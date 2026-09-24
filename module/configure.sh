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
  printf 'Exact glasses Bluetooth display name: '
  IFS= read -r GLASSES_NAME || { echo 'Configuration cancelled.'; exit 1; }
  # Accept a CRLF terminal input stream without accepting embedded whitespace.
  INPUT_CR=$(printf '\r')
  HEADSET_INPUT=${HEADSET_INPUT%"$INPUT_CR"}
  GLASSES_INPUT=${GLASSES_INPUT%"$INPUT_CR"}
  GLASSES_NAME=${GLASSES_NAME%"$INPUT_CR"}
  set -- "$HEADSET_INPUT" "$GLASSES_INPUT" "$GLASSES_NAME"
elif [ "$#" != 3 ]; then
  echo 'Usage: sh configure.sh [HEADSET_ADDRESS GLASSES_ADDRESS "GLASSES_DISPLAY_NAME"]'; exit 1
fi
GLASSES_NAME=$3
if [ -z "$GLASSES_NAME" ] || [ "${#GLASSES_NAME}" -gt 80 ] ||
   [ "$GLASSES_NAME" != "$(printf '%s' "$GLASSES_NAME" | LC_ALL=C tr -d '[:cntrl:]')" ]; then
  echo 'Invalid glasses display name (no control characters, brackets or backslash).'; exit 1
fi
case "$GLASSES_NAME" in ' '*|*' ') echo 'Remove leading/trailing spaces from glasses name.'; exit 1 ;; esac
case "$GLASSES_NAME" in *'['*|*']'*|*'\'*) echo 'Brackets and backslash are not supported in the display name.'; exit 1 ;; esac
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
TEMP_NAME="$MODDIR/glasses-name.configuring.$$"
trap 'rm -f "$TEMP_BUNDLE" "$TEMP_NAME"' EXIT
sed -e "s/HEADSET_BLUETOOTH_ADDRESS/$HEADSET/g" \
    -e "s/GLASSES_DEVICE_RECORD_ADDRESS/$GLASSES/g" \
    "$MODDIR/background.template.js" > "$TEMP_BUNDLE"
chmod 600 "$TEMP_BUNDLE"
printf '%s\n' "$GLASSES_NAME" > "$TEMP_NAME"
chmod 600 "$TEMP_NAME"
mv "$TEMP_NAME" "$MODDIR/glasses-name"
mv "$TEMP_BUNDLE" "$MODDIR/background.js"
echo 'Configured locally. Reboot the phone to start. Do not share background.js.'
