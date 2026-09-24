# Installation and device selection

The module requires KernelSU, a primary-user Android arm64 installation, Meta AI **289.0.0.25.162 / 968902270**, connected Meta glasses and an A2DP Bluetooth headset. No headset brand or model is preselected.

## First installation

1. Install `meta-earbud-background-v1.1.0-public.zip` through KernelSU and reboot.
2. Open a root terminal, or run `adb shell` followed by `su`.
3. Run the setup command below. Enter your own headset and glasses addresses at the first two prompts, then the exact glasses Bluetooth display name at the third.

```sh
sh /data/adb/modules/meta-earbud-background/configure.sh
```

4. Reboot again. Keep the glasses connected and connect the selected headset. Check that Pause and Battery saver enable; disconnect the headset to check restoration.

The module remains inactive until configured. Setup accepts uppercase or lowercase colon-separated addresses and normalizes them. It rejects malformed, identical, all-zero and broadcast addresses.

## Finding the correct addresses

Use the Bluetooth address of the headset that actually establishes the A2DP connection, and the Bluetooth / DeviceRecord address that Meta AI uses for your glasses. Do not enter the phone's address, a device name, an account identifier or a serial number.

Some Android versions show a paired device's address on its Bluetooth device details page. If yours does not, local Bluetooth diagnostics such as `adb shell dumpsys bluetooth_manager` may list paired devices and their addresses. These diagnostics can contain details about all paired devices: inspect them locally instead of posting the full output. If Android masks the addresses or the glasses' DeviceRecord differs, the correct values must be established before setup; there is no automatic device discovery in this version.

Both addresses and the unique glasses display name are required. The connection gate reads the selected name's live BR/EDR or LE ACL state from the bonded-device section of `dumpsys bluetooth_manager`. This avoids relying on masked addresses; unsupported dump formats or duplicate names fail closed for new work. The display name is not a wear sensor. Backslashes, brackets, control characters and leading/trailing spaces are not accepted. A headset being paired is not enough; it must connect using A2DP. Only the selected headset triggers the module. To use a different headset, follow the device-change procedure below.

## Configuration storage

Setup saves the display name as a root-readable plain-text `glasses-name` file (never sourced as shell code) and generates a root-readable script inside the installed module directory. The original downloaded ZIP stays address-free. Do not redistribute the generated script or make a public ZIP from a configured installation.

For scripted installation, setup also accepts two address arguments and a quoted display name:

```sh
sh /data/adb/modules/meta-earbud-background/configure.sh HEADSET_ADDRESS GLASSES_ADDRESS "GLASSES_DISPLAY_NAME"
```

The interactive prompts are preferable when you do not want addresses in shell command history. Entered values still belong to local device configuration and are necessarily available to root.

## Upgrading, changing devices and removing

Disconnect the selected headset while the glasses remain connected. Confirm that the previous Pause and Battery saver values have returned. Uninstall the old module and reboot before installing the new version. Configure the new installation and reboot once more.

Do not skip restoration or the reboot when switching versions. A previous adapter can remain in the Meta AI process until it exits. Setup refuses to overwrite a configured script, and new installations require fresh device selection.

The KernelSU **Action** button displays status. `WAITING_FOR_CONFIGURATION` means setup has not completed. `WAITING_FOR_GLASSES` means the selected glasses are not available to Meta AI. Unsupported app builds are not activated.

This is an experimental module. It does not provide audio forwarding or universal compatibility across Android ROMs and glasses firmware.

## Disconnected idle behavior in 1.1.0

The controller checks every 60 seconds while disconnected/unknown, 30 seconds while connected, without wake alarms. No Meta package lookup, service startup or injection occurs while disconnected. The module stops its own listener once, not the app. Confirm reconnection and restoration yourself before relying on the pre-release. A suspended phone may delay checks. If the name changes, follow the device-change procedure; do not edit or share a configured bundle.
