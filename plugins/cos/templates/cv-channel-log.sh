#!/usr/bin/env bash
# Turns on or off a log of {{AGENT_NAME}}'s Carbon Voice connection, and shows it.
#   ./cv-channel-log.sh on      start logging, from the next ./start-cos.sh
#   ./cv-channel-log.sh off     stop logging, from the next ./start-cos.sh
#   ./cv-channel-log.sh         show whether logging is on, and the last 40 lines
#   ./cv-channel-log.sh follow  watch the log as it's written (Ctrl+C to stop)
# The log is .cv/channel.log. It records what the connection does, by ID: connecting, messages
# received or dropped, pairing codes, errors. It never records your token or what was said.
set -euo pipefail
cd "$(dirname "$0")"
FLAG=.cv/channel-log.on
LOG=.cv/channel.log
case "${1:-show}" in
  on)
    mkdir -p .cv; touch "$FLAG"
    echo "Logging is on. It starts the next time your agent starts:"
    echo "if it's running, type /exit in its window, then run ./start-cos.sh."
    echo "To watch it: ./cv-channel-log.sh follow" ;;
  off)
    rm -f "$FLAG"
    echo "Logging is off from the next start. The log so far is kept in $LOG." ;;
  show)
    if [[ -e "$FLAG" ]]; then echo "Logging is on."; else echo "Logging is off. To turn it on: ./cv-channel-log.sh on"; fi
    if [[ -s "$LOG" ]]; then echo "Last 40 lines of $LOG:"; echo; tail -n 40 "$LOG"; else echo "There's no log yet."; fi ;;
  follow)
    if [[ ! -e "$FLAG" ]]; then echo "Logging is off, so nothing new will appear. To turn it on: ./cv-channel-log.sh on"; fi
    touch "$LOG"; tail -n 20 -f "$LOG" ;;
  *)
    echo "Usage: ./cv-channel-log.sh [on | off | follow]"; exit 1 ;;
esac
