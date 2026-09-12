"""Host-side checks for the public release configuration and packaging boundaries."""
import hashlib
import importlib.util
import lzma
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / "dist/meta-earbud-background-v1.0.2-public.zip"
BASH = os.environ.get("TEST_BASH") or shutil.which("bash")
HEADSET = ":".join(["02", "00", "00", "00", "00", "01"])
GLASSES = ":".join(["02", "00", "00", "00", "00", "02"])


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / "build")
        self.folder = Path(self.temp.name)
        with zipfile.ZipFile(PUBLIC) as archive:
            archive.extractall(self.folder)

    def tearDown(self):
        self.temp.cleanup()

    def configure(self, *args, input_text=None):
        # Simulate root for a host-only configuration fixture, never a phone.
        return subprocess.run([BASH, "-c", 'id() { echo 0; }; export -f id; exec bash "$@"',
                               "fixture", (self.folder / "configure.sh").as_posix(), *args],
                              capture_output=True, text=True, input=input_text)

    def test_public_archive_is_inactive_and_contains_no_configuration(self):
        self.assertFalse((self.folder / "background.js").exists())
        template = (self.folder / "background.template.js").read_text(encoding="utf-8")
        self.assertEqual(template.count("HEADSET_BLUETOOTH_ADDRESS"), 1)
        self.assertEqual(template.count("GLASSES_DEVICE_RECORD_ADDRESS"), 1)
        self.assertNotIn("sourceMappingURL=", template)
        self.assertNotIn(HEADSET, template)
        self.assertNotIn(GLASSES, template)
        self.assertTrue((self.folder / "licenses/frida-core-COPYING").exists())

    def test_configuration_changes_only_two_placeholders(self):
        result = self.configure(HEADSET.lower(), GLASSES.lower())
        self.assertEqual(result.returncode, 0, result.stderr)
        template = (self.folder / "background.template.js").read_text(encoding="utf-8")
        configured = (self.folder / "background.js").read_text(encoding="utf-8")
        self.assertEqual(configured, template.replace("HEADSET_BLUETOOTH_ADDRESS", HEADSET).replace("GLASSES_DEVICE_RECORD_ADDRESS", GLASSES))
        self.assertNotIn(HEADSET, result.stdout)
        self.assertNotIn(GLASSES, result.stdout)
        subprocess.run(["node", "--check", str(self.folder / "background.js")], check=True, capture_output=True)
        # Configuration must not silently change devices/restore-state ownership.
        before = (self.folder / "background.js").read_bytes()
        self.assertNotEqual(self.configure(GLASSES, HEADSET).returncode, 0)
        self.assertEqual(before, (self.folder / "background.js").read_bytes())

    def test_invalid_and_shell_inputs_never_generate_a_bundle(self):
        for first, second in [(HEADSET, HEADSET), (": ".join(["00"] * 6), GLASSES),
                              (":".join(["00"] * 6), GLASSES), (":".join(["FF"] * 6), GLASSES),
                              ("$(touch SHOULD_NOT_EXIST)", GLASSES),
                              (HEADSET + "\ninvalid", GLASSES), (HEADSET, "invalid")]:
            with self.subTest(first_length=len(first)):
                result = self.configure(first, second)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.folder / "background.js").exists())
        self.assertFalse((ROOT / "SHOULD_NOT_EXIST").exists())

    def test_interactive_setup_uses_the_installing_users_addresses(self):
        headset = ":".join(["02", "AB", "CD", "EF", "11", "22"])
        glasses = ":".join(["02", "BA", "DC", "FE", "33", "44"])
        result = self.configure(input_text=f"{headset.lower()}\n{glasses.lower()}\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        configured = (self.folder / "background.js").read_text(encoding="utf-8")
        self.assertIn(headset, configured)
        self.assertIn(glasses, configured)
        self.assertNotIn(HEADSET, configured)
        self.assertNotIn(GLASSES, configured)
        self.assertNotIn(headset, result.stdout)
        self.assertNotIn(glasses, result.stdout)

    def test_cancelled_interactive_setup_stays_inactive(self):
        result = self.configure(input_text=HEADSET + "\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.folder / "background.js").exists())

    def test_builder_rejects_device_specific_configuration(self):
        import sys
        result = subprocess.run([sys.executable, str(ROOT / "scripts/build.py"), "--config", "unused.json"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unrecognized arguments", result.stderr)

    def test_listener_filters_by_selected_address_not_brand_or_other_devices(self):
        # Evaluate the actual selector against fake Java Bluetooth devices.
        import json
        source = (ROOT / "src/background.js").read_text(encoding="utf-8")
        source = "\n".join(line for line in source.splitlines() if not line.startswith("import "))
        runner = r'''
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[2], 'utf8');
const context = vm.createContext({console, Java: {perform() {}, use() {return {};}, cast(value) {return value;}}});
vm.runInContext(source, context);
const selected = process.argv[3];
function check(addresses, expected) {
  context.devices = addresses.map(address => ({getAddress() {return address;}}));
  const actual = vm.runInContext('profile = {getConnectedDevices() {return {size() {return devices.length;}, get(i) {return devices[i];}};}}; connectedNow()', context);
  if (actual !== expected) throw new Error('Incorrect headset selection');
}
check([], false);
check([process.argv[4]], false);
check([selected.toLowerCase()], true);
check([process.argv[4], selected], true);
'''
        source_file = self.folder / "selector.js"
        source_file.write_text(f"const HEADSET={json.dumps(HEADSET)}, GLASSES={json.dumps(GLASSES)};\n" + source, encoding="utf-8")
        runner_file = self.folder / "check-selector.cjs"
        runner_file.write_text(runner, encoding="utf-8")
        subprocess.run(["node", str(runner_file), str(source_file), HEADSET, GLASSES], check=True, capture_output=True)

    def test_shell_scripts_parse(self):
        for script in self.folder.glob("*.sh"):
            subprocess.run([BASH, "-n", script.as_posix()], check=True, capture_output=True)

    def test_injector_matches_verified_upstream_archive(self):
        archive = os.environ.get("TEST_FRIDA_XZ")
        if not archive:
            self.skipTest("Set TEST_FRIDA_XZ to check the downloaded upstream binary")
        spec = importlib.util.spec_from_file_location("builder", ROOT / "scripts/build.py")
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        compressed = Path(archive).read_bytes()
        self.assertEqual(hashlib.sha256(compressed).hexdigest(), builder.FRIDA_SHA256)
        self.assertEqual((self.folder / "meta-inject").read_bytes(), lzma.decompress(compressed))


if __name__ == "__main__":
    unittest.main()
