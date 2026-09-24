#!/bin/sh
set -eu
MODDIR=$1
. "$MODDIR/policy.sh"
GLASSES_NAME="Example Glasses"
STATE=$(mktemp -d)
trap 'rm -f "$STATE/events" "$STATE/status" "$STATE/agent.pid"; rmdir "$STATE"' EXIT
: > "$STATE/events"
passed=0
assert_eq() {
  if [ "$1" != "$2" ]; then echo "FAIL $3: expected=$2 actual=$1"; exit 1; fi
  passed=$((passed+1))
}
fixture() {
  printf 'Bluetooth Status\n  enabled: true\nBluetoothRemoteDevices\n  Bonded devices: 2\n'
  printf '    AA [ DUAL ] [ACL BR/EDR:%s LE:%s] [ Encryption: null ] %s\n' "$1" "$2" "${3:-Example Glasses}"
  printf '    BB [ DUAL ] [ACL BR/EDR:Y LE:N] [ Encryption: yes ] HUAWEI WATCH GT 4\nNextSection\n'
}
assert_eq "$(fixture N N | parse_glasses)" disconnected 'watch alone'
assert_eq "$(fixture Y N | parse_glasses)" connected BR
assert_eq "$(fixture N Y | parse_glasses)" connected LE
assert_eq "$(fixture Y Y | parse_glasses)" connected both
assert_eq "$(fixture Y N 'Example Glasses other' | parse_glasses)" unknown 'exact name'
assert_eq "$(fixture '?' N | parse_glasses)" unknown 'unknown ACL'
assert_eq "$(printf 'Bluetooth Status\n  enabled: false\n' | parse_glasses)" disconnected disabled
assert_eq "$(printf 'history: [ACL BR/EDR:Y LE:N] [ x ] Example Glasses\n' | parse_glasses)" unknown history
assert_eq "$( { fixture N N; fixture Y N; } | parse_glasses)" unknown ambiguity
assert_eq "$(printf '' | parse_glasses)" unknown empty
assert_eq "$(controller_pid_valid 99999999 && echo yes || echo no)" no stale_pid
assert_eq "$(controller_pid_valid $$ && echo yes || echo no)" no unrelated_pid

# Test actual policy, replacing only platform calls with observable fakes.
probe_glasses() { echo "$TEST_CONNECTION"; }
meta_pid() { echo "$TEST_PID"; }
meta_version() { echo version >> "$STATE/events"; echo "$TEST_VERSION"; }
start_meta() { echo start >> "$STATE/events"; }
send_stop() { echo stop >> "$STATE/events"; return "$STOP_RESULT"; }
inject_meta() { echo inject >> "$STATE/events"; return "$INJECT_RESULT"; }
reset_case() {
  LAST_PID=; LAST_STATUS=; VERSION=; CHECKED_PID=; START_BACKOFF=0
  TEST_PID=100; TEST_VERSION=$SUPPORTED_VERSION; INJECT_RESULT=0; STOP_RESULT=0
  : > "$STATE/events"
}
events() { tr '\n' ',' < "$STATE/events"; }
reset_case
TEST_CONNECTION=disconnected
policy_step
assert_eq "$(events)" '' 'disconnected no calls'
assert_eq "$NEXT_SLEEP" 60 idle_interval
LAST_PID=100
policy_step
policy_step
assert_eq "$(events)" 'stop,' 'one stop on disconnect'
TEST_CONNECTION=connected
policy_step
policy_step
assert_eq "$(events)" 'stop,version,inject,' 'reconnect and cached version'
assert_eq "$NEXT_SLEEP" 30 connected_interval
TEST_CONNECTION=unknown
policy_step
assert_eq "$(events)" 'stop,version,inject,' 'unknown does not churn'
reset_case
TEST_CONNECTION=connected; TEST_VERSION=unsupported
policy_step
policy_step
assert_eq "$(events)" 'version,' 'mismatch no injection'
reset_case
TEST_CONNECTION=connected; TEST_PID=
policy_step
policy_step
policy_step
policy_step
policy_step
assert_eq "$(events)" 'version,start,' 'five-minute start backoff'
policy_step
assert_eq "$(events)" 'version,start,version,start,' 'bounded retry'
reset_case
TEST_CONNECTION=connected; INJECT_RESULT=1
policy_step
assert_eq "$(events)" 'version,inject,stop,' 'partial injection cleanup'
assert_eq "$NEXT_SLEEP" 60 failure_interval
reset_case
TEST_CONNECTION=disconnected; LAST_PID=100; STOP_RESULT=1
policy_step || true
assert_eq "$LAST_PID" 100 'retain stop ownership on failure'
assert_eq "$(events)" 'stop,' 'failed stop no start'
reset_case
GLASSES_NAME=
policy_step
assert_eq "$(events)" '' 'unconfigured no platform work'
assert_eq "$LAST_STATUS" 'WAITING_FOR_CONFIGURATION: see INSTALL.md' unconfigured_status
echo "PASS $passed assertions"
