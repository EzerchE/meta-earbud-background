# v1.1.0 — disconnected-glasses idle gate (pre-release)

- Do not start Meta AI or inject while the configured glasses are disconnected.
- Stop the module's own listener on confirmed disconnection; preserve Meta's native app and reconnection handling.
- Replace ten-second package polling with 60-second idle / 30-second connected checks and per-process version validation. Retry failed startup at most once per five minutes.
- Add singleton locking, PID identity checks, bounded commands and streaming Bluetooth dump parsing.
- Setup now also asks for the exact glasses Bluetooth display name. No personal name/address is bundled. Both Meta version name and versionCode remain enforced.
- Audio routing, glasses setting logic, original restore points and pinned Frida version are unchanged.

## Validation boundary

The personalized controller was checked on Nothing Phone (1) / crDroid Android 16 with glasses disconnected. Public packaging/configuration tests and controller policy fixtures cover failure paths; actual public fresh-install reconnect/restoration remains pending. No quantified battery saving or zero-RAM claim. Unknown/ambiguous Bluetooth dumps do not trigger new work. Checks can be delayed by system sleep.

Follow the restore/uninstall/reboot/reconfigure upgrade procedure in INSTALL.md. Do not share a configured installation or logs.

Validation for this archive: 12 host release/configuration tests passed, including 27 controller-policy assertions; the same 27 assertions passed on Android shell. Installed Meta version-name/versionCode parsing was verified read-only. Public ZIP privacy scan found none of the reference installation's private device identifiers. Pinned upstream injector checksum passed.

ZIP SHA-256: `39f0dedb413370a170d3faa5b64492ba81011355fec870860134c0c9c891c7eb`.
