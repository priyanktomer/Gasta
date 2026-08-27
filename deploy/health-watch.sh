#!/usr/bin/env bash
#
# Notice when the API stops answering (PLAN-6 §B-4).
#
# `docker compose logs` was the whole of monitoring: the health endpoint exists
# and does a real round trip to MySQL, and nothing looked at it. A server that
# died at 2am stayed dead until somebody opened the app.
#
# This is not monitoring. It is the smallest thing that turns "nobody knows"
# into "the log says". Deliberately no third-party service, no account and no
# agent — see the note at the bottom for what a real one would need.
#
# Install on the server:
#
#   sudo cp deploy/health-watch.sh /opt/gasta/
#   sudo chmod +x /opt/gasta/health-watch.sh
#   ( crontab -l 2>/dev/null; echo "*/5 * * * * /opt/gasta/health-watch.sh" ) | crontab -
#
set -uo pipefail

URL="${GASTA_HEALTH_URL:-https://yapan.duckdns.org/api/v1/yapan/common/health}"
STATE="${GASTA_HEALTH_STATE:-/tmp/gasta-health.state}"
LOG="${GASTA_HEALTH_LOG:-/var/log/gasta-health.log}"

# ⚠️ Two failures before it says anything, five minutes apart.
#
# A single timeout is a dropped packet, a certificate renewal, or the API
# restarting after a deploy — all of which resolve themselves. Shouting about
# every one of those is how somebody learns to ignore this file, and then it
# stops working for the case it exists for.
THRESHOLD="${GASTA_HEALTH_THRESHOLD:-2}"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# --max-time, not just --connect-timeout: a server that accepts the connection
# and then hangs is the failure this is most likely to see, and a connect
# timeout alone would wait for ever on it.
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$URL" || echo 000)

fails=0
[ -f "$STATE" ] && fails=$(cat "$STATE" 2>/dev/null || echo 0)

if [ "$code" = "200" ]; then
  # Recovery is worth a line too. Without it the log shows a server going down
  # and never coming back, which is a worse story than the truth.
  if [ "$fails" -ge "$THRESHOLD" ]; then
    echo "$(stamp) RECOVERED after $fails failed check(s)" >> "$LOG"
  fi
  echo 0 > "$STATE"
  exit 0
fi

fails=$((fails + 1))
echo "$fails" > "$STATE"

if [ "$fails" -ge "$THRESHOLD" ]; then
  echo "$(stamp) DOWN http=$code ($fails consecutive)" >> "$LOG"
fi
exit 1

# ⚠️ **This reaches a person only if they read the file.**
#
# It has no way to wake anybody, which is the difference between this and
# monitoring. What would close that gap, cheapest first:
#
#   - An external pinger (UptimeRobot's free tier, Healthchecks.io) that emails
#     when the ping *stops* — which also catches the case this cannot: the
#     whole host being gone, cron included.
#   - Telegram or email from this script, which needs a token in .env.
#
# The external one is better precisely because it does not run here.
