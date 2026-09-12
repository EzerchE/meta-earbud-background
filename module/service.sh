#!/system/bin/sh
MODDIR=${0%/*}
umask 077
STATE=/data/adb/meta-earbud-background
mkdir -p "$STATE"
chmod 700 "$STATE"
if [ -f "$STATE/service.pid" ] && kill -0 "$(cat "$STATE/service.pid")" 2>/dev/null; then exit 0; fi
echo $$ > "$STATE/service.pid"
LAST_PID=
cleanup() {
  am broadcast -a io.github.metaearbud.background.STOP_BACKGROUND -p com.facebook.stella >/dev/null 2>&1
  rm -f "$STATE/service.pid"
}
trap 'cleanup; exit 0' TERM INT
while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 5; done
while [ ! -f "$MODDIR/disable" ] && [ ! -f "$MODDIR/remove" ]; do
  if [ ! -s "$MODDIR/background.js" ]; then
    echo "WAITING_FOR_CONFIGURATION: see INSTALL.md" > "$STATE/status"
    sleep 30
    continue
  fi
  VER=$(dumpsys package com.facebook.stella | sed -n 's/.*versionName=//p' | head -n 1)
  CODE=$(dumpsys package com.facebook.stella | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -n 1)
  if [ "$VER" != "289.0.0.25.162" ] || [ "$CODE" != "968902270" ]; then
    [ -n "$LAST_PID" ] && am broadcast -a io.github.metaearbud.background.STOP_BACKGROUND -p com.facebook.stella >/dev/null 2>&1
    LAST_PID=
    echo "Unsupported Meta AI version: $VER; no injection" > "$STATE/status"
    sleep 60
    continue
  fi
  META_PID=$(pidof com.facebook.stella | awk '{print $1}')
  if [ -z "$META_PID" ]; then
    # Start Meta's existing media/device foreground service, never an Activity.
    am start-foreground-service -n com.facebook.stella/com.facebook.wearable.companion.mediaexchange.coreimpl.sourcemanager.MediaSourceService >/dev/null 2>&1
    sleep 10
    META_PID=$(pidof com.facebook.stella | awk '{print $1}')
  fi
  if [ -z "$META_PID" ]; then sleep 30; continue; fi
  if [ "$META_PID" != "$LAST_PID" ]; then
    [ -f "$STATE/agent.log" ] && mv -f "$STATE/agent.log" "$STATE/agent.previous.log"
    if "$MODDIR/meta-inject" -e -p "$META_PID" -s "$MODDIR/background.js" > "$STATE/agent.log" 2>&1; then
      LAST_PID=$META_PID
      echo "Attached to Meta AI pid=$META_PID" > "$STATE/status"
    else
      echo "Attach failed; waiting before retry" > "$STATE/status"
      sleep 60
    fi
  fi
  sleep 10
done
cleanup
