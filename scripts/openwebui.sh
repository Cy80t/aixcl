#!/usr/bin/env bash
set -e

# Always run inside the backend root (required by uvicorn import path)
cd /app/backend || exit 1

KEY_FILE=/app/backend/.webui_secret_key
PORT="${PORT:-8080}"
HOST="${HOST:-0.0.0.0}"

echo "[AIXCL] Starting Open WebUI bootstrap"
echo "  Working directory: $(pwd)"
echo "  Host: $HOST"
echo "  Port: $PORT"


# ------------------------------------------------------------
# Secret key handling (same logic as original)
# ------------------------------------------------------------
if test "$WEBUI_SECRET_KEY $WEBUI_JWT_SECRET_KEY" = " "; then
  echo "[AIXCL] Loading WEBUI_SECRET_KEY from file..."

  if ! [ -e "$KEY_FILE" ]; then
    echo "[AIXCL] Creating new WEBUI_SECRET_KEY"
    head -c 12 /dev/random | base64 > "$KEY_FILE"
  fi

  WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
fi


# ------------------------------------------------------------
# TEMPORARY START - for migrations and admin creation
# ------------------------------------------------------------
echo "[AIXCL] Starting temporary Open WebUI instance..."

WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" \
  uvicorn open_webui.main:app \
    --host "$HOST" \
    --port "$PORT" \
    --forwarded-allow-ips '*' &

webui_pid=$!
echo "[AIXCL] Waiting for /health..."

until curl -s "http://localhost:${PORT}/health" > /dev/null; do
  sleep 1
done


# ------------------------------------------------------------
# Create admin user (ignore errors)
# ------------------------------------------------------------
echo "[AIXCL] Creating admin user (if not exists)..."

curl \
  -X POST "http://localhost:${PORT}/api/v1/auths/signup" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{ \"email\": \"${OPENWEBUI_EMAIL}\", \"password\": \"${OPENWEBUI_PASSWORD}\", \"name\": \"Admin\" }" \
  >/dev/null 2>&1 || true


echo "[AIXCL] Shutting down temporary server..."
kill "$webui_pid" || true
sleep 1


# ------------------------------------------------------------
# FINAL START
# ------------------------------------------------------------
echo "[AIXCL] Starting Open WebUI (final)..."

WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" \
  exec uvicorn open_webui.main:app \
    --host "$HOST" \
    --port "$PORT" \
    --forwarded-allow-ips '*'
