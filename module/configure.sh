#!/system/bin/sh
# Configure the public template locally. Never evaluate user input as shell code.
set -eu
umask 077
MODDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$(id -u)" != 0 ]; then echo 'Run through a root shell.'; exit 1; fi
if [ "$#" = 0 ]; then
  printf 'Headset Bluetooth address: '
  IFS= read -r HEADSET_INPUT || { echo 'Configuration cancelled.'; exit 1; }
  printf 'Glasses Bluetooth / DeviceRecord address: '
  IFS= read -r GLASSES_INPUT || { echo 'Configuration cancelled.'; exit 1; }
  # Accept a CRLF terminal input stream without accepting embedded whitespace.
  INPUT_CR=$(printf '\r')
  HEADSET_INPUT=${HEADSET_INPUT%"$INPUT_CR"}
  GLASSES_INPUT=${GLASSES_INPUT%"$INPUT_CR"}
  set -- "$HEADSET_INPUT" "$GLASSES_INPUT"
elif [ "$#" != 2 ]; then
  echo 'Usage: sh configure.sh [HEADSET_ADDRESS GLASSES_ADDRESS]'; exit 1
fi
valid_address() {
  [ "${#1}" = 17 ] || return 1
  case "$1" in *[!0-9A-F:]*) return 1 ;; esac
  printf '%s\n' "$1" | LC_ALL=C grep -Eq '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' &&
    [ "$1" != '00:00:00:00:00:00' ] && [ "$1" != 'FF:FF:FF:FF:FF:FF' ]
}
HEADSET=$(printf '%s' "$1" | tr 'a-f' 'A-F')
GLASSES=$(printf '%s' "$2" | tr 'a-f' 'A-F')
if ! valid_address "$HEADSET" || ! valid_address "$GLASSES" || [ "$HEADSET" = "$GLASSES" ]; then
  echo 'Invalid or identical Bluetooth addresses.'; exit 1
fi
if [ ! -f "$MODDIR/background.template.js" ]; then echo 'Public template not found.'; exit 1; fi
if [ -e "$MODDIR/background.js" ]; then
  echo 'Already configured. Disconnect the headset, restore settings, then reinstall before changing devices.'
  exit 1
fi
TEMP_BUNDLE="$MODDIR/background.configuring.$$"
trap 'rm -f "$TEMP_BUNDLE"' EXIT
sed -e "s/HEADSET_BLUETOOTH_ADDRESS/$HEADSET/g" \
    -e "s/GLASSES_DEVICE_RECORD_ADDRESS/$GLASSES/g" \
    "$MODDIR/background.template.js" > "$TEMP_BUNDLE"
chmod 600 "$TEMP_BUNDLE"
mv "$TEMP_BUNDLE" "$MODDIR/background.js"
echo 'Configured locally. Reboot the phone to start. Do not share background.js.'
