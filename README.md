# Meta Earbud Background

**English** | [Türkçe](README.tr.md)

A KernelSU module that enables **Pause** and **Battery saver** on Meta glasses when your selected Bluetooth earbuds or headset connect. When they disconnect, the previous settings are restored. It works in the background with the phone screen off, without UI taps.

The module does **not** redirect glasses audio to earbuds.

## Requirements

- A rooted Android arm64 phone with KernelSU, using the primary Android user profile.
- Meta AI **289.0.0.25.162**, versionCode **968902270**. Other app builds are rejected because the module relies on private app methods.
- Connected Meta glasses and a Bluetooth headset with an **A2DP** connection. Pairing alone is not enough.

No headset brand, model, account or device address is built into the module. Each installation selects its own headset and glasses. Zygisk and LSPosed are not required.

This is an experimental module. Android 16 is the reference platform; compatibility with other ROMs, glasses firmware and headset combinations is not guaranteed.

## Install and configure

1. Download `meta-earbud-background-v1.0.2-public.zip` from [Releases](../../releases).
2. Install it through **KernelSU → Modules → Install**, then reboot.
3. Open a root terminal, or run `adb shell` followed by `su`.
4. Start setup:

```sh
sh /data/adb/modules/meta-earbud-background/configure.sh
```

5. At the prompts, enter your headset's Bluetooth address and your glasses' Bluetooth / Meta DeviceRecord address. Use colon-separated addresses, not device names or serial numbers.
6. Reboot. With the glasses connected, connect your headset and check that both settings enable. Disconnect it and check that the previous values return.

The ZIP is inactive until configured. Addresses are entered locally and are not included in the downloaded package. No source compilation is needed for installation. See the [installation guide](docs/release-install.md) for address lookup and upgrades.

## Behavior

| Event | Result |
| --- | --- |
| Selected headset connects | Save previous settings; enable Pause and Battery saver. |
| Selected headset disconnects | Restore previous settings. |
| Another headset connects | Ignore it. |
| Screen is off | Continue in the background. |
| Glasses are unavailable | Wait for their connection. |
| Unsupported Meta AI build | Do not activate the adapter. |

Connection changes are debounced for about 2.5 seconds. Synchronizing Battery saver may take around 10 seconds. Pause is set for eight hours and renewed hourly while the headset stays connected; an existing longer pause is preserved. Battery saver applies Meta's normal restrictions, including its effect on the wake word.

## Status and troubleshooting

Use the module's **Action** button in KernelSU, or:

```sh
adb shell su -c 'cat /data/adb/meta-earbud-background/status'
```

- `WAITING_FOR_CONFIGURATION`: run setup and reboot.
- `WAITING_FOR_GLASSES`: make sure the glasses are powered on and connected to Meta AI.
- `HEADSET_CONNECTED=false`: verify the selected headset's address and active A2DP connection.
- `VERIFY_FAILED`: reconnect the glasses/headset and check the settings in Meta AI.
- `RESTORE_POINT_WRITE_FAILED`: previous settings could not be saved, so that attempt did not change the glasses settings.
- `Unsupported Meta AI version`: the installed Meta AI build is not supported.

Keep configured scripts and device logs on your own phone; they can contain device identifiers or operational details. Clearing Meta AI data removes the saved restore state.

## Upgrade, change devices or uninstall

Disconnect the selected headset while the glasses remain connected and confirm that the previous settings have returned. Uninstall the old module and reboot before installing a replacement, then configure it again. Setup refuses to overwrite an existing configuration.

Stopping or uninstalling the module does not itself restore the glasses settings. A reboot removes callbacks from an older adapter; it is required when switching versions. Restoration cannot be verified while the glasses are disconnected.

## Build from source

Clone this repository using its **Code** menu, then run:

```sh
cd meta-earbud-background
npm ci
python scripts/build.py
```

Requirements: Node.js/npm, Python 3.10+ and internet access for the official Frida download. Windows may use `py -3` instead of `python`. Android SDK and Gradle are not required.

The builder always produces the same address-free template type as the public download. It does not read local device configuration. Output: `dist/meta-earbud-background-v1.0.2-public.zip`.

An existing official Frida archive can be supplied with `--inject-xz /path/to/frida-inject-17.18.0-android-arm64.xz`. Its pinned SHA-256 is verified before packaging. Third-party notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

This project is independent and is not affiliated with Meta or KernelSU.
