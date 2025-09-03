# Termux-like Web Terminal on Render with Wetty + Postgres snapshots
# Base with Node >= 18 so Wetty works
FROM node:20-bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV TZ=Etc/UTC

# Essentials + Postgres client (no X11, keep it slim)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git build-essential \
    python3 python3-pip python3-venv \
    zsh tmux htop vim nano unzip net-tools iputils-ping \
    openssh-client gnupg locales procps sudo \
    postgresql-client \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Wetty (browser terminal)
RUN npm i -g wetty

# Create Termux-like user
RUN useradd -m -s /bin/zsh spaceuser \
 && echo "spaceuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/spaceuser \
 && chmod 0440 /etc/sudoers.d/spaceuser

USER spaceuser
WORKDIR /home/spaceuser

# Minimal Zsh config (Termux feel)
RUN { echo 'export TERM=xterm-256color'; \
      echo 'PS1="%F{cyan}termux@%m:%~%f\n$ "'; \
      echo 'alias ll="ls -alF"'; \
      echo 'alias pkg="sudo apt-get"'; \
      echo 'alias tx="/usr/local/bin/tx"'; \
    } >> ~/.zshrc

# Snapshot helper (tx): save/restore/history using Postgres Large Objects
USER root
RUN cat <<'TX' >/usr/local/bin/tx
#!/usr/bin/env bash
set -euo pipefail

need_db() {
  if [ -z "${DATABASE_URL:-}" ]; then
    echo "❌ DATABASE_URL is not set." >&2
    exit 1
  fi
}

case "${1:-}" in
  save)
    need_db
    tmp=/tmp/termuxfs.tar.gz
    tar -czf "$tmp" -C /home/spaceuser .
    # Import file as Large Object and record its OID atomically
    psql "$DATABASE_URL" <<'SQL'
\set ON_ERROR_STOP on
CREATE TABLE IF NOT EXISTS termuxfs_lo (
  id serial PRIMARY KEY,
  ts timestamptz DEFAULT now(),
  lo_oid oid NOT NULL
);
\lo_import /tmp/termuxfs.tar.gz
INSERT INTO termuxfs_lo(lo_oid) VALUES (:LASTOID);
SQL
    echo "✅ Snapshot saved."
    ;;
  restore)
    need_db
    OID="$(psql "$DATABASE_URL" -t -A -c "SELECT lo_oid FROM termuxfs_lo ORDER BY ts DESC LIMIT 1")"
    if [ -z "$OID" ]; then
      echo "⚠️  No snapshots found."
      exit 0
    fi
    psql "$DATABASE_URL" -c "\lo_export $OID /tmp/termuxfs.tar.gz"
    tar -xzf /tmp/termuxfs.tar.gz -C /home/spaceuser
    chown -R spaceuser:spaceuser /home/spaceuser
    echo "✅ Snapshot restored (OID $OID)."
    ;;
  history)
    need_db
    psql "$DATABASE_URL" -c "SELECT id, ts, lo_oid FROM termuxfs_lo ORDER BY ts DESC LIMIT 20;"
    ;;
  *)
    echo "tx usage:"
    echo "  tx save      # snapshot /home/spaceuser to Postgres"
    echo "  tx restore   # restore latest snapshot"
    echo "  tx history   # list recent snapshots"
    exit 1
    ;;
esac
TX
RUN chmod +x /usr/local/bin/tx && chown spaceuser:spaceuser /usr/local/bin/tx

# Start script: restore, autosave, then run Wetty in foreground
RUN cat <<'START' >/usr/local/bin/start-termux-twin.sh
#!/usr/bin/env bash
set -euo pipefail
PORT="${PORT:-10000}"
echo "🚀 Container start: $(date)"
if [ -n "${DATABASE_URL:-}" ]; then
  echo "🔄 Restoring home from Postgres..."
  sudo -u spaceuser /usr/local/bin/tx restore || true
else
  echo "ℹ️ DATABASE_URL not set; starting without persistence."
fi

# Background autosave every 5 minutes
if [ -n "${DATABASE_URL:-}" ]; then
  ( while true; do
      sleep 300
      echo "💾 Autosaving snapshot at $(date)..."
      sudo -u spaceuser /usr/local/bin/tx save || echo "⚠️ Autosave failed"
    done ) &
fi

echo "✅ Launching Wetty on 0.0.0.0:${PORT}"
# Run Wetty in foreground (keeps the container alive)
exec sudo -u spaceuser wetty --host 0.0.0.0 --port "$PORT" --base / --allow-iframe --command /bin/zsh
START
RUN chmod +x /usr/local/bin/start-termux-twin.sh

# Run as the normal user
USER spaceuser
EXPOSE 10000
CMD ["/usr/local/bin/start-termux-twin.sh"]
