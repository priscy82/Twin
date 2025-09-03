FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV TZ=Etc/UTC

# Install essentials + Postgres client + Wetty deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git build-essential \
    python3 python3-pip python3-venv \
    nodejs npm \
    zsh tmux htop vim nano unzip net-tools iputils-ping \
    openssh-client gnupg locales procps \
    cmake make gcc g++ postgresql-client pkg-config \
    libjson-c-dev libwebsockets-dev \
 && npm install -g wetty \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create Termux-like user (no sudo)
RUN useradd -m -s /bin/zsh spaceuser

USER spaceuser
WORKDIR /home/spaceuser

# Configure Zsh
RUN { echo 'export TERM=xterm-256color'; \
      echo 'PS1="%F{cyan}termux@%m:%~%f\n$ "'; \
      echo 'alias ll="ls -alF"'; \
      echo 'alias pkg="apt-get"'; } >> ~/.zshrc

USER root

# Snapshot helper (tx)
RUN cat <<'EOF' > /usr/local/bin/tx
#!/bin/bash
set -e
ACTION=$1
shift || true

if [ -z "$DATABASE_URL" ]; then
  echo "❌ DATABASE_URL not set"
  exit 1
fi

PGPASSWORD=$(echo $DATABASE_URL | sed -E 's|.*:([^@]*)@.*|\1|')
PGHOST=$(echo $DATABASE_URL | sed -E 's|.*@([^:/]*):.*|\1|')
PGUSER=$(echo $DATABASE_URL | sed -E 's|postgres://([^:]*):.*|\1|')
PGDB=$(echo $DATABASE_URL | sed -E 's|.*/([^?]*)|\1|')

case "$ACTION" in
  save)
    tar -cz -C /home/spaceuser . | base64 | \
      psql -h $PGHOST -U $PGUSER -d $PGDB -c \
      "INSERT INTO termuxfs (data) VALUES (decode('$(cat)', 'escape'));" ;;
  restore)
    psql -h $PGHOST -U $PGUSER -d $PGDB -c \
      "CREATE TABLE IF NOT EXISTS termuxfs (id serial primary key, ts timestamptz default now(), data bytea);" >/dev/null 2>&1
    psql -h $PGHOST -U $PGUSER -d $PGDB -t -c \
      "SELECT encode(data,'escape') FROM termuxfs ORDER BY ts DESC LIMIT 1;" \
      | tail -n 1 | base64 -d | tar -xz -C /home/spaceuser || echo "⚠️ No snapshot found" ;;
  history)
    psql -h $PGHOST -U $PGUSER -d $PGDB -c "SELECT id, ts FROM termuxfs ORDER BY ts DESC LIMIT 20;" ;;
  *)
    echo "Usage: tx {save|restore|history}"
    exit 1 ;;
esac
EOF

RUN chmod +x /usr/local/bin/tx

# Startup script
RUN cat <<'EOF' > /usr/local/bin/start-termux-twin.sh
#!/bin/bash
set -e
PORT=${PORT:-10000}

echo "🚀 Container started at $(date)"

# Restore snapshot if available
if [ -n "${DATABASE_URL:-}" ]; then
  echo "🔄 Restoring home from Postgres..."
  /usr/local/bin/tx restore || true
fi

# Launch Wetty in foreground
echo "✅ Launching Wetty on 0.0.0.0:$PORT"
exec wetty --host 0.0.0.0 --port "$PORT" --base / --allow-iframe --command /bin/zsh
EOF

RUN chmod +x /usr/local/bin/start-termux-twin.sh

USER spaceuser
EXPOSE 10000
CMD ["/usr/local/bin/start-termux-twin.sh"]
