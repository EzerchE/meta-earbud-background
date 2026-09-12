#!/system/bin/sh
am broadcast -a io.github.metaearbud.background.STOP_BACKGROUND -p com.facebook.stella >/dev/null 2>&1
STATE=/data/adb/meta-earbud-background
if [ -f "$STATE/service.pid" ]; then kill "$(cat "$STATE/service.pid")" 2>/dev/null; fi
# Preserve the restore point inside Meta AI; it belongs to an unfinished session.
