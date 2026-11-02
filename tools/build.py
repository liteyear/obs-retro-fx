"""Build the OBS-ready folder and reproducible public ZIP; Python stdlib only."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "src/upstream-shaders"
VERSION = (ROOT / "VERSION").read_text().strip()
PRODUCT = "Liteyear-Retro-FX"


def expand(path):
    text = path.read_text(encoding="utf-8")
    return re.sub(r'^#include "([^"]+)"\s*$',
                  lambda match: expand(path.parent / match[1]), text, flags=re.M)


def main():
    out = [f"-- Liteyear Retro FX {VERSION} | GPL-2.0\n"
           "-- Adapted from FiniteSingularity/obs-retro-effects 1.1.1.\n"
           "-- Editable source and original attribution are included.\n"
           "local SHADERS = {}\n"]
    unused = {"bloom-threshold", "noise-functions", "gaussian_1d", "gaussian_1d_texture",
              "dual_kawase_down_sample", "dual_kawase_up_sample"}
    for path in sorted(SHADERS.glob("*.effect")):
        if path.stem not in unused:
            out.append(f"SHADERS[{json.dumps(path.stem)}] = [====[\n{expand(path)}\n]====]\n")
    out.append("SHADERS.custom = [====[\n" + (ROOT / "src/custom.effect").read_text(encoding="utf-8") + "\n]====]\n")
    runtime = (ROOT / "src/runtime.lua").read_text(encoding="utf-8")
    assert f'local VERSION = "{VERSION}"' in runtime, "Runtime/VERSION mismatch"
    out.append(runtime)
    package = ROOT / "package" / PRODUCT
    package.mkdir(parents=True, exist_ok=True)
    (package / "liteyear-retro-fx.lua").write_text("".join(out), encoding="utf-8")
    shutil.copytree(ROOT / "assets", package / "assets", dirs_exist_ok=True)
    for name in ["README.md", "LICENSE", "CREDITS.md", "CHANGELOG.md"]:
        shutil.copy2(ROOT / name, package / name)
    for name in ["START-HERE.html", "TEST-REPORT.md"]:
        shutil.copy2(ROOT / "docs" / name, package / name)
    source = package / "Source"
    for name in ["src", "assets", "tools"]:
        shutil.copytree(ROOT / name, source / name, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    for name in ["VERSION", "README.md", "LICENSE", "CREDITS.md", "CHANGELOG.md"]:
        shutil.copy2(ROOT / name, source / name)
    shutil.copytree(ROOT / "docs", source / "docs", dirs_exist_ok=True)
    (source / "tests").mkdir(exist_ok=True)
    for path in (ROOT / "tests").iterdir():
        if path.suffix in {".py", ".c"}:
            shutil.copy2(path, source / "tests" / path.name)
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    archive = dist / f"{PRODUCT}-{VERSION}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for path in sorted(package.rglob("*")):
            if not path.is_file():
                continue
            entry = zipfile.ZipInfo(path.relative_to(package.parent).as_posix(), (2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            output.writestr(entry, path.read_bytes())
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (dist / "SHA256SUMS.txt").write_text(f"{digest}  {archive.name}\n", encoding="ascii")
    print(f"Built {archive.name} ({archive.stat().st_size:,} bytes)")
    print(f"SHA256 {digest}")


if __name__ == "__main__":
    main()
