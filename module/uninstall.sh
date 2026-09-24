#!/system/bin/sh
MODDIR=${0%/*}
STATE=/data/adb/meta-earbud-background
. "$MODDIR/policy.sh"
p=$(cat "$STATE/service.pid" 2>/dev/null)
if controller_pid_valid "$p"; then kill "$p" 2>/dev/null; fi
send_stop
# Keep restore preferences. No app force-stop and no Bluetooth changes.
