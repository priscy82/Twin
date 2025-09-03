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
