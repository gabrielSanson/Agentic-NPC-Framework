#!/usr/bin/env bash
# Starts the model servers for one demo profile in the background, one after another, and waits until each one
# answers its health check (at most 180 s each). PIDs go to servers/.pids; logs go to servers/<name>.log.
# Stop them with stop_all.sh.
# Usage: start_all.sh [--profile light|full|text_only]     (default: light)
set -euo pipefail
source "$(dirname "$0")/common.sh"

PROFILE="light"
while [ $# -gt 0 ]; do
	case "$1" in
		--profile) PROFILE="${2:-}"; shift 2 ;;
		--profile=*) PROFILE="${1#--profile=}"; shift ;;
		*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done

case "$PROFILE" in
	light) SERVERS=(gemma kev parakeet breeze) ;;
	full) SERVERS=(gemma kev parakeet breeze) ;;
	text_only) SERVERS=(gemma kev) ;;
	*) echo "profile must be light, full or text_only" >&2; exit 2 ;;
esac

# Extra flags per server for each profile (one flag per output line).
flags_for() {
	case "$PROFILE:$1" in
		light:kev) echo --light ;;
		light:parakeet) echo --cpu ;;
		light:breeze) echo --light ;;
	esac
}

# Health URL and strictness per server. Strict (1) means only 200 counts. Otherwise any answer below 500 counts.
health_of() {
	case "$1" in
		gemma) echo "http://127.0.0.1:$GEMMA_PORT/v1/models 0" ;;
		kev) echo "http://127.0.0.1:$KEV_PORT/v1/models 0" ;;
		parakeet) echo "http://127.0.0.1:$PARAKEET_PORT/health 1" ;;
		breeze) echo "http://127.0.0.1:$BREEZE_PORT/ 0" ;;
	esac
}

if [ -f "$PIDS_FILE" ]; then
	echo "Servers are already recorded in $PIDS_FILE. Run stop_all.sh first." >&2
	exit 1
fi

# Waits until the server answers, or fails when its process has exited or 180 s pass.
wait_ready() { # name pid url strict
	local name="$1" pid="$2" url="$3" strict="$4" code
	for _ in $(seq 1 180); do
		if ! kill -0 "$pid" 2>/dev/null; then
			echo "$name exited early; see $SERVERS_DIR/$name.log" >&2
			return 1
		fi
		code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$url" || true)
		if [ "$strict" = 1 ] && [ "$code" = "200" ]; then
			return 0
		fi
		if [ "$strict" = 0 ] && [ "$code" -ge 200 ] 2>/dev/null && [ "$code" -lt 500 ]; then
			return 0
		fi
		sleep 1
	done
	echo "$name did not answer at $url within 180 s; see $SERVERS_DIR/$name.log" >&2
	return 1
}

: > "$PIDS_FILE"
for name in "${SERVERS[@]}"; do
	mapfile -t extra < <(flags_for "$name")
	nohup "$SERVERS_DIR/start_$name.sh" ${extra[@]+"${extra[@]}"} > "$SERVERS_DIR/$name.log" 2>&1 &
	pid=$!
	echo "$name $pid" >> "$PIDS_FILE"
	read -r url strict <<< "$(health_of "$name")"
	echo "waiting for $name at $url"
	wait_ready "$name" "$pid" "$url" "$strict"
	echo "ready: $name"
done
echo "All servers for profile $PROFILE answer. Run the smoke check next."
