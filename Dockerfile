FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV TZ=Etc/UTC

# Install essentials
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git build-essential \
    python3 python3-pip python3-venv \
    nodejs npm \
    zsh tmux htop vim nano unzip net-tools iputils-ping \
    openssh-client gnupg locales procps sudo \
    cmake make gcc g++ postgresql-client \
    ttyd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create Termux-like user
RUN useradd -m -s /bin/zsh spaceuser \
 && echo "spaceuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/spaceuser \
 && chmod 0440 /etc/sudoers.d/spaceuser

USER spaceuser
WORKDIR /home/spaceuser

# Configure Zsh
RUN { echo 'export TERM=xterm-256color'; \
      echo 'PS1="%F{cyan}termux@%m:%~%f\n$ "'; \
      echo 'alias ll="ls -alF"'; } >> ~/.zshrc

USER root
EXPOSE 10000

# Add smart pkg wrapper (Postgres snapshot manager)
RUN cat <<'EOF' > /usr/local/bin/pkg
#!/bin/bash
set -e

# --- Parse DATABASE_URL if available ---
if [ -n "$DATABASE_URL" ]; then
  export POSTGRES_USER=$(echo $DATABASE_URL | sed -E 's#postgres://([^:]+):.*#\1#')
  export POSTGRES_PASSWORD=$(echo $DATABASE_URL | sed -E 's#postgres://[^:]+:([^@]+)@.*#\1#')
  export POSTGRES_HOST=$(echo $DATABASE_URL | sed -E 's#postgres://[^@]+@([^:/]+).*#\1#')
  export POSTGRES_DB=$(echo $DATABASE_URL | sed -E 's#.*/([^/?]+).*#\1#')
fi

cmd="$1"; shift || true
case "$cmd" in
  save)
    echo "💾 Saving snapshot..."
    tar czf - /home/spaceuser | \
      PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB \
      -c "CREATE TABLE IF NOT EXISTS termuxfs (id serial primary key, ts timestamptz default now(), data bytea);
          INSERT INTO termuxfs (data) VALUES (pg_read_binary_file('/dev/stdin'));" || true
    ;;
  restore)
    echo "📦 Restoring snapshot..."
    latest=$(PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -t -c \
      "SELECT id FROM termuxfs ORDER BY ts DESC LIMIT 1;")
    if [ -n "$latest" ]; then
      PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -t -A -c \
        "SELECT encode(data,'base64') FROM termuxfs WHERE id=$latest;" | base64 -d | tar xzf - -C /
      echo "✅ Restored snapshot #$latest"
    else
      echo "⚠️ No snapshots found"
    fi
    ;;
  history)
    PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB \
      -c "SELECT id, ts FROM termuxfs ORDER BY ts DESC LIMIT 10;"
    ;;
  *)
    exec sudo apt-get "$cmd" "$@"
    ;;
esac
EOF
RUN chmod +x /usr/local/bin/pkg

# Startup script: restore + ttyd + autosave
RUN cat <<'EOF' > /usr/local/bin/start-termux-twin.sh
#!/bin/bash
set -e
PORT=${PORT:-10000}

echo "🚀 Container started at $(date)"

# Restore last snapshot if any
pkg restore

# Start ttyd on the given port
echo "✅ Launching Termux Twin on port $PORT..."
ttyd -p $PORT zsh &

# Auto-save every 5 minutes
while true; do
  sleep 300
  pkg save
done
EOF

RUN chmod +x /usr/local/bin/start-termux-twin.sh

CMD ["/usr/local/bin/start-termux-twin.sh"]
