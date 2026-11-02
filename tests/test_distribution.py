"""Check public identity, assets and release integrity without an OBS install."""
import hashlib
import importlib.util
from pathlib import Path
import re
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release_build", ROOT / "tools/build.py")
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class DistributionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build.main()
        cls.archive = ROOT / "dist" / f"Liteyear-Retro-FX-{build.VERSION}.zip"
        cls.lua = (ROOT / "package/Liteyear-Retro-FX/liteyear-retro-fx.lua").read_text()

    def test_filter_identity_is_public_and_unique(self):
        definitions = re.findall(r'local \w+ = def\("([^"]+)"', self.lua)
        self.assertEqual(len(definitions), 15)
        self.assertEqual(len(set(definitions)), 15)
        self.assertIn('id="liteyear_retro_"..current.id.."_v1"', self.lua)
        self.assertIn('get_name=function() return "Liteyear FX - "..current.label end', self.lua)
        self.assertIn(f'local VERSION = "{build.VERSION}"', self.lua)

    def test_assets_source_and_license_are_in_archive(self):
        with zipfile.ZipFile(self.archive) as archive:
            self.assertIsNone(archive.testzip())
            names = set(archive.namelist())
            prefix = "Liteyear-Retro-FX/"
            for name in ["liteyear-retro-fx.lua", "LICENSE", "CREDITS.md", "START-HERE.html",
                         "Source/src/runtime.lua", "Source/tools/build.py"]:
                self.assertIn(prefix + name, names)
            for path in (ROOT / "assets").glob("*.png"):
                self.assertEqual(archive.read(prefix + "assets/" + path.name), path.read_bytes())
            self.assertFalse(any("render.log" in name or "__pycache__" in name for name in names))
            self.assertFalse(any(name.startswith("/") or ".." in Path(name).parts for name in names))

    def test_checksum_and_reproducible_build(self):
        before = self.archive.read_bytes()
        digest = hashlib.sha256(before).hexdigest()
        self.assertEqual((ROOT / "dist/SHA256SUMS.txt").read_text().split()[0], digest)
        build.main()
        self.assertEqual(before, self.archive.read_bytes())


if __name__ == "__main__":
    unittest.main()
