#!/usr/bin/env bash
# Prueba de red: un servidor real y varios clientes headless.
# Uso: tests/net_smoke.sh [puerto]
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PORT=${1:-7799}
LOGS=$(mktemp -d)
# Se lanza como escena porque el modo --script no compila los autoloads.
client() { timeout 20 "$GODOT" --headless --path . res://tests/smoke_client.tscn -- --port "$PORT" "$@"; }

"$GODOT" --headless --path . -- --server --port "$PORT" --mode line_1v1 >"$LOGS/server.log" 2>&1 &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null' EXIT
sleep 2

client --expect accept >"$LOGS/a.log" 2>&1 & A=$!
client --expect accept >"$LOGS/b.log" 2>&1 & B=$!
sleep 2
client --expect reject >"$LOGS/full.log" 2>&1 & FULL=$!
client --expect reject --version 0.0.0 >"$LOGS/version.log" 2>&1 & VERSION=$!

FAILED=0
for name in A B FULL VERSION; do
	wait "${!name}" || { echo "FALLA cliente $name"; FAILED=1; }
done
grep -hE '^(PASA|FALLA)|SCRIPT ERROR|ERROR:' "$LOGS"/*.log
echo "Registros en $LOGS"
exit "$FAILED"
