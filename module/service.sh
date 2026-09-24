#!/system/bin/sh
MODDIR=${0%/*}
STATE=/data/adb/meta-earbud-background
umask 077
mkdir -p "$STATE"
chmod 700 "$STATE"
. "$MODDIR/policy.sh"
exec 9>"$STATE/controller.lock"
# Android mksh marks persistent descriptors close-on-exec unless redirected.
flock -n 9 9>&9 || exit 0
old_pid=$(cat "$STATE/service.pid" 2>/dev/null)
if controller_pid_valid "$old_pid"; then exit 0; fi
printf '%s\n' "$$" > "$STATE/service.pid"
LAST_PID=$(cat "$STATE/agent.pid" 2>/dev/null)
LAST_STATUS=
CHECKED_PID=
VERSION=
START_BACKOFF=0
cleanup() {
  stop_owned_agent
  [ "$(cat "$STATE/service.pid" 2>/dev/null)" != "$$" ] || rm -f "$STATE/service.pid"
}
trap 'exit 0' TERM INT
trap cleanup EXIT
while [ "$(getprop sys.boot_completed)" != 1 ]; do
  [ ! -f "$MODDIR/disable" ] && [ ! -f "$MODDIR/remove" ] || exit 0
  sleep 5 9>&-
done
while [ ! -f "$MODDIR/disable" ] && [ ! -f "$MODDIR/remove" ]; do
  policy_step
  sleep "$NEXT_SLEEP" 9>&-
done
