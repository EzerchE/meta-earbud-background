"""Build an address-free module ZIP for configuration on each user's phone."""
import argparse
import hashlib
import lzma
from pathlib import Path
import shutil
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FRIDA_VERSION = "17.18.0"
FRIDA_URL = f"https://github.com/frida/frida/releases/download/{FRIDA_VERSION}/frida-inject-{FRIDA_VERSION}-android-arm64.xz"
FRIDA_SHA256 = "a72de74276d914f6769b8b85f8dd287cbafa4527c42ae1c8dd87b0d23d261391"
MODULE_VERSION = "1.0.2"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    # Retain the old public switch as a no-op for existing build instructions.
    parser.add_argument("--public", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--inject-xz", type=Path, help="Use an already downloaded official Frida archive")
    args = parser.parse_args()
    compiler = ROOT / "node_modules/frida-compile/dist/cli.js"
    node = shutil.which("node")
    if not node or not compiler.is_file():
        raise SystemExit("Install Node.js and run npm ci first")
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    # No local device configuration is read, generated or embedded by this builder.
    # IIFE permits validated placeholder replacement; source maps are omitted.
    subprocess.run([node, str(compiler), "src/background.js", "-B", "iife", "-S", "-o", "build/background.js"], cwd=ROOT, check=True)

    archive = args.inject_xz or build / f"frida-inject-{FRIDA_VERSION}-android-arm64.xz"
    if not archive.exists():
        if args.inject_xz:
            raise FileNotFoundError(archive)
        print(f"Downloading official Frida inject {FRIDA_VERSION}")
        with urllib.request.urlopen(FRIDA_URL, timeout=90) as response:
            archive.write_bytes(response.read())
    compressed = archive.read_bytes()
    if hashlib.sha256(compressed).hexdigest() != FRIDA_SHA256:
        raise ValueError("Frida archive SHA-256 mismatch; refusing to package")
    injector = lzma.decompress(compressed)
    if not injector.startswith(b"\x7fELF"):
        raise ValueError("Expected an ELF executable")
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    output = dist / f"meta-earbud-background-v{MODULE_VERSION}-public.zip"
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as package:
        for name in ("action.sh", "configure.sh", "customize.sh", "module.prop", "service.sh", "uninstall.sh"):
            source = ROOT / "module" / name
            entry = zipfile.ZipInfo(name)
            entry.external_attr = (0o100755 if source.suffix == ".sh" else 0o100644) << 16
            package.writestr(entry, source.read_bytes().replace(b"\r\n", b"\n"), compress_type=zipfile.ZIP_DEFLATED)
        package.write(build / "background.js", "background.template.js")
        entry = zipfile.ZipInfo("meta-inject")
        entry.external_attr = 0o100755 << 16
        package.writestr(entry, injector, compress_type=zipfile.ZIP_DEFLATED)
        package.write(ROOT / "THIRD_PARTY_NOTICES.md", "THIRD_PARTY_NOTICES.md")
        for source in sorted((ROOT / "licenses").iterdir()):
            if source.is_file():
                package.write(source, f"licenses/{source.name}")
        package.write(ROOT / "docs/release-install.md", "INSTALL.md")
    print(f"Built {output.name}; SHA-256: {hashlib.sha256(output.read_bytes()).hexdigest()}")
    print("Address-free template: configure on-device before use.")


if __name__ == "__main__":
    main()
