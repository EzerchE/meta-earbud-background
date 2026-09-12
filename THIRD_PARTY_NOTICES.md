# Third-party components

The module uses the following third-party components.

The build tool downloads **Frida inject 17.18.0 for Android arm64** from its official release and verifies the archive SHA-256 before packaging it. The JavaScript bundle includes **frida-java-bridge 7.0.13**. The compiler is **frida-compile 19.0.5**; dependency versions are recorded in `package-lock.json`.

- [Frida 17.18.0 release](https://github.com/frida/frida/releases/tag/17.18.0)
- [Frida core 17.18.0 source and license](https://github.com/frida/frida-core/tree/17.18.0)
- [Frida Gum 17.18.0 source and notices](https://github.com/frida/frida-gum/tree/17.18.0)
- [Frida Java Bridge 7.0.13 source revision](https://github.com/frida/frida-java-bridge/tree/6ab2a63e4b02ab881f11ea06632cebea4b1b435e)
- [Frida compile source and license](https://github.com/frida/frida-compile)

Frida core and Gum carry the wxWindows Library Licence 3.1 (GNU Library GPL v2 or later with the wxWindows exception). Frida Java Bridge's npm package declares `LGPL-2.0 WITH WxWindows-exception-3.1`; its exact source revision above comes from the npm `gitHead` metadata. The upstream core/Gum notices and GNU Library GPL v2 text are included in `licenses/` and in the module ZIP. The core notice includes the wxWindows exception text applicable to the bridge's declared license as well; it is not presented as a separate license file retrieved from the bridge repository.

The public ZIP redistributes the unmodified official Android arm64 injector; it does not modify Frida itself. Its compressed upstream asset is verified against SHA-256 `a72de74276d914f6769b8b85f8dd287cbafa4527c42ae1c8dd87b0d23d261391`. The injector can be replaced locally by rebuilding from upstream. The [Frida 17.18.0 source tree and build instructions](https://github.com/frida/frida/tree/17.18.0) identify its components; core and Gum subproject wrap files identify additional upstream dependencies, which retain their own licenses. The compiler and its npm dependencies are build tools and are not shipped as an installed Node.js runtime.

The distributed ZIP is an address-free template. Configured on-device scripts contain the installing user's device selection and are not redistributable release assets.

Meta, Ray-Ban and KernelSU names belong to their respective owners. This project is independent and is not endorsed by them.
