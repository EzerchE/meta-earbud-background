# v1.1.1 — Unsupported-build idle safety (pre-release)

- Check Meta package compatibility once at startup, before Bluetooth probing.
- Stop the controller on unsupported/unreadable builds instead of polling with
  no possible benefit. Reboot after installing a compatible adapter/app to retry.
- Bound PID validation to a 4096-byte, two-second procfs read, including a process
  exiting while its identity is being checked.
- Preserve private adapter guards and existing headset/glasses selection rules.

**Still requires Meta AI 289.0.0.25.162 / 968902270. This is not support for
Meta 290.1, universal app-version compatibility or Bluetooth call repair.**

Validation: 33 policy assertions on Android; 12 host packaging/configuration
tests including the pinned Frida archive verification. The configured controller
exited correctly with an unsupported app on Spacewar. Fresh public-install
physical reconnection and glasses-setting restoration remain unverified.

The ZIP is address-free and inactive until configured. Read the installation
guide before upgrading: restoring glasses settings and rebooting matter when
replacing an attached adapter. No measured battery-savings claim.
