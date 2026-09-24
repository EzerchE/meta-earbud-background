#!/system/bin/sh
# Sourced by controller and tests; no actions while sourcing.
PACKAGE=com.facebook.stella
SUPPORTED_VERSION=289.0.0.25.162/968902270
GLASSES_NAME=$(cat "$MODDIR/glasses-name" 2>/dev/null || true)
STOP_ACTION=io.github.metaearbud.background.STOP_BACKGROUND
parse_glasses() {
  awk -v target="$GLASSES_NAME" '
    /^Bluetooth Status[[:space:]]*$/ { status=1; next }
    status && /^[[:space:]]+enabled: false[[:space:]]*$/ { disabled=1 }
    status && /^[^[:space:]]/ { status=0 }
    /^BluetoothRemoteDevices[[:space:]]*$/ { remote=1; next }
    remote && /^[^[:space:]]/ { remote=0 }
    remote && /Bonded devices:/ { bonded=1; next }
    remote && bonded && /\[ACL / {
      name=$0; sub(/^.*\] /,"",name); sub(/[[:space:]]+$/,"",name)
      if (name != target) next
      matches++
      if ($0 ~ /\[ACL BR\/EDR:[YN] LE:[YN]\]/) {
        valid++
        if ($0 ~ /\[ACL BR\/EDR:Y LE:[YN]\]/ || $0 ~ /\[ACL BR\/EDR:[YN] LE:Y\]/) connected=1
      }
    }
    END {
      if (disabled) print "disconnected"
      else if (matches != 1 || valid != 1) print "unknown"
      else if (connected) print "connected"
      else print "disconnected"
    }'
}
controller_pid_valid() {
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ -r "/proc/$1/cmdline" ] || return 1
  tr '\000' '\n' < "/proc/$1/cmdline" | grep -Fxq "$MODDIR/service.sh"
}
set_status() {
  [ "${LAST_STATUS:-}" = "$1" ] && return
  LAST_STATUS=$1
  printf '%s\n' "$1" > "$STATE/status"
}
probe_glasses() {
  # Stream the potentially multi-MB dump, retaining only the one-word result.
  # Android mksh pipefail prevents accepting a truncated/timeout dump.
  result=$(set -o pipefail; timeout 8 dumpsys bluetooth_manager 9>&- 2>/dev/null | parse_glasses) || { echo unknown; return; }
  printf '%s\n' "$result"
}
meta_pid() { pidof "$PACKAGE" 2>/dev/null | awk '{print $1}'; }
meta_version() {
  result=$(set -o pipefail; timeout 8 dumpsys package "$PACKAGE" 9>&- 2>/dev/null |
    awk '/^[[:space:]]*versionName=/ {sub(/^.*versionName=/,""); name=$0}
      /^[[:space:]]*versionCode=/ {sub(/^.*versionCode=/,""); sub(/ .*/,""); code=$0}
      END {if(name != "" && code != "") print name "/" code}') || return 1
  printf '%s\n' "$result"
}
start_meta() {
  timeout 10 am start-foreground-service -n "$PACKAGE/com.facebook.wearable.companion.mediaexchange.coreimpl.sourcemanager.MediaSourceService" 9>&- >/dev/null 2>&1
}
send_stop() { timeout 10 am broadcast -a "$STOP_ACTION" -p "$PACKAGE" 9>&- >/dev/null 2>&1; }
inject_meta() {
  [ ! -f "$STATE/agent.log" ] || mv -f "$STATE/agent.log" "$STATE/agent.previous.log"
  timeout 20 "$MODDIR/meta-inject" -e -p "$1" -s "$MODDIR/background.js" 9>&- > "$STATE/agent.log" 2>&1
}
stop_owned_agent() {
  [ -n "${LAST_PID:-}" ] || return 0
  if ! send_stop; then
    set_status 'Stop delivery failed; retry pending, no new injection'
    return 1
  fi
  LAST_PID=
  rm -f "$STATE/agent.pid"
}
policy_step() {
  NEXT_SLEEP=60
  if [ ! -s "$MODDIR/background.js" ] || [ -z "$GLASSES_NAME" ]; then
    stop_owned_agent || return
    set_status 'WAITING_FOR_CONFIGURATION: see INSTALL.md'
    return
  fi
  connection=$(probe_glasses)
  case "$connection" in
    disconnected)
      stop_owned_agent || return
      set_status 'Glasses disconnected: automation idle; no app start or injection'
      return ;;
    connected) ;;
    *) set_status 'Glasses state unknown: no app start or injection'; return ;;
  esac
  candidate_pid=$(meta_pid)
  if [ -z "$candidate_pid" ]; then
    LAST_PID=
    rm -f "$STATE/agent.pid"
    if [ "${START_BACKOFF:-0}" -gt 0 ]; then
      START_BACKOFF=$((START_BACKOFF - 1))
      set_status 'Glasses connected: native app start backoff'
      return
    fi
    VERSION=$(meta_version)
    if [ "$VERSION" != "$SUPPORTED_VERSION" ]; then
      set_status 'Unsupported or unreadable Meta version: automation idle'
      return
    fi
    start_meta
    START_BACKOFF=4
    set_status 'Glasses connected: app start requested, waiting for process'
    return
  fi
  START_BACKOFF=0
  if [ "$candidate_pid" = "${LAST_PID:-}" ]; then
    NEXT_SLEEP=30
    return
  fi
  if [ "$candidate_pid" != "${CHECKED_PID:-}" ] || [ -z "${VERSION:-}" ]; then
    VERSION=$(meta_version)
    CHECKED_PID=$candidate_pid
  fi
  if [ "$VERSION" != "$SUPPORTED_VERSION" ]; then
    stop_owned_agent || return
    set_status 'Unsupported or unreadable Meta version: automation idle'
    return
  fi
  stop_owned_agent || return
  LAST_PID=$candidate_pid
  printf '%s\n' "$LAST_PID" > "$STATE/agent.pid"
  if inject_meta "$candidate_pid"; then
    set_status "Attached to Meta AI pid=$candidate_pid; glasses connected"
    NEXT_SLEEP=30
  else
    stop_owned_agent
    set_status 'Injection failed: retry after 60s; no forced app restart'
  fi
}
