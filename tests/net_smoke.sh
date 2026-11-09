#!/usr/bin/env bash
# Prueba de red: servidores reales y varios clientes headless.
# Uso: tests/net_smoke.sh [puerto]
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PORT=${1:-7799}
COMBAT_PORT=$((PORT + 1))
LOGS=$(mktemp -d)
# Se lanza como escena porque el modo --script no compila los autoloads.
client() { timeout 20 "$GODOT" --headless --path . res://tests/smoke_client.tscn -- "$@"; }
menu() { timeout 20 "$GODOT" --headless --path . res://tests/menu_smoke.tscn -- "$@"; }

"$GODOT" --headless --path . -- --server --port "$PORT" --mode line_1v1 >"$LOGS/server.log" 2>&1 &
SERVER=$!
"$GODOT" --headless --path . -- --server --port "$COMBAT_PORT" --mode hero_test >"$LOGS/combat_server.log" 2>&1 &
COMBAT_SERVER=$!
trap 'kill "$SERVER" "$COMBAT_SERVER" 2>/dev/null' EXIT
sleep 2

client --port "$PORT" --expect accept >"$LOGS/a.log" 2>&1 & A=$!
client --port "$PORT" --expect accept --jump >"$LOGS/b.log" 2>&1 & B=$!
client --port "$COMBAT_PORT" --expect accept --hero arcanist --cast 1 >"$LOGS/ranged.log" 2>&1 & RANGED=$!
client --port "$COMBAT_PORT" --expect accept --hero guardian --cast 1 >"$LOGS/melee.log" 2>&1 & MELEE=$!
sleep 2
client --port "$PORT" --expect reject >"$LOGS/full.log" 2>&1 & FULL=$!
client --port "$PORT" --expect reject --version 0.0.0 >"$LOGS/version.log" 2>&1 & VERSION=$!
client --port "$COMBAT_PORT" --expect reject --hero nadie >"$LOGS/hero.log" 2>&1 & HERO=$!
menu --port "$COMBAT_PORT" --expect enter >"$LOGS/menu.log" 2>&1 & MENU=$!
menu --port "$((PORT + 2))" --expect fail >"$LOGS/menu_noserver.log" 2>&1 & NOSERVER=$!

FAILED=0
for name in A B RANGED MELEE FULL VERSION HERO MENU NOSERVER; do
	wait "${!name}" || { echo "FALLA cliente $name"; FAILED=1; }
done
grep -hE '^(PASA|FALLA)|SCRIPT ERROR|ERROR:' "$LOGS"/*.log
echo "Registros en $LOGS"
exit "$FAILED"
