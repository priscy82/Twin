FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV TZ=Etc/UTC

# Install essentials + ttyd build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git build-essential \
    python3 python3-pip python3-venv \
    nodejs npm \
    zsh tmux htop vim nano unzip net-tools iputils-ping \
    openssh-client gnupg locales procps sudo \
    cmake make gcc g++ postgresql-client pkg-config \
    libjson-c-dev libwebsockets-dev \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Build ttyd from source
RUN git clone --depth=1 https://github.com/tsl0922/ttyd.git /tmp/ttyd \
 && cd /tmp/ttyd && mkdir build && cd build \
 && cmake .. && make && make install \
 && cd / && rm -rf /tmp/ttyd

# Create Termux-like user
RUN useradd -m -s /bin/zsh spaceuser \
 && echo "spaceuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/spaceuser \
 && chmod 0440 /etc/sudoers.d/spaceuser

USER spaceuser
WORKDIR /home/spaceuser

# Configure Zsh
RUN { echo 'export TERM=xterm-256color'; \
      echo 'PS1="%F{cyan}termux@%m:%~%f\n$ "'; \
      echo 'alias ll="ls -alF"'; \
      echo 'alias pkg="sudo apt-get"'; } >> ~/.zshrc

USER root
EXPOSE 10000

# Startup script
RUN cat <<'EOF' > /usr/local/bin/start-termux-twin.sh
#!/bin/bash
set -e
PORT=${PORT:-10000}

echo "🚀 Container started at $(date)"

# --- Restore from Postgres ---
if [ -n "$DATABASE_URL" ]; then
  echo "🔄 Restoring /home/spaceuser from Postgres..."
  export PGPASSWORD=$(echo $DATABASE_URL | sed -E 's|.*:([^@]*)@.*|\1|')
  PGHOST=$(echo $DATABASE_URL | sed -E 's|.*@([^:/]*):.*|\1|')
  PGUSER=$(echo $DATABASE_URL | sed -E 's|postgres://([^:]*):.*|\1|')
  PGDB=$(echo $DATABASE_URL | sed -E 's|.*/([^?]*)|\1|')

  psql -h $PGHOST -U $PGUSER -d $PGDB -c \
    "CREATE TABLE IF NOT EXISTS termuxfs (id serial primary key, ts timestamptz default now(), data bytea);" >/dev/null 2>&1

  psql -h $PGHOST -U $PGUSER -d $PGDB -t -c \
    "SELECT encode(data,'escape') FROM termuxfs ORDER BY ts DESC LIMIT 1;" \
    | tail -n 1 | base64 -d | tar -xz -C /home/spaceuser || echo "⚠️ No snapshot found"
fi

# --- Auto-save snapshot in background ---
if [ -n "$DATABASE_URL" ]; then
  (
    while true; do
      sleep 300
      echo "💾 Saving snapshot to Postgres..."
      tar -cz -C /home/spaceuser . | base64 | \
        psql -h $PGHOST -U $PGUSER -d $PGDB -c \
        "INSERT INTO termuxfs (data) VALUES (decode('$(cat)', 'escape'));" || echo "⚠️ Snapshot failed"
    done
  ) &
fi

# --- Start ttyd in foreground ---
echo "✅ Launching Termux Twin on port $PORT..."
exec ttyd -p $PORT zsh
EOF

RUN chmod +x /usr/local/bin/start-termux-twin.sh

CMD ["/usr/local/bin/start-termux-twin.sh"]
