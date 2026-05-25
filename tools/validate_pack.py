#!/usr/bin/env python3
"""Validate one or more apxm-libs pack directories.

Checks:
  * pack.toml parses and declares pack_id, version, skill, license.
  * [source] block is well-formed:
      - kind ∈ {"original", "port"}.
      - When kind = "port": upstream, upstream_path, upstream_commit,
        upstream_license, attribution are required.
  * skills/<skill>/ exists and contains a valid skill bundle
    (delegated to validate_skill.py).
  * For port packs: skills/<skill>/upstream/SKILL.md is present.

Exit code 0 on success, 1 on any failure.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

REQUIRED_TOP = ("pack_id", "version", "skill", "license")
REQUIRED_SOURCE = ("kind", "attribution")
PORT_REQUIRED = ("upstream", "upstream_path", "upstream_commit", "upstream_license")
VALID_KINDS = {"original", "port"}


def _fail(path: Path, msg: str) -> None:
    print(f"FAIL {path}: {msg}", file=sys.stderr)


def validate_pack(pack_dir: Path) -> int:
    failures = 0
    manifest_path = pack_dir / "pack.toml"
    if not manifest_path.exists():
        _fail(pack_dir, "missing pack.toml")
        return 1
    try:
        manifest = tomllib.loads(manifest_path.read_text())
    except tomllib.TOMLDecodeError as exc:
        _fail(manifest_path, f"TOML parse error: {exc}")
        return 1

    for field in REQUIRED_TOP:
        if not manifest.get(field):
            _fail(manifest_path, f"missing required field: {field}")
            failures += 1

    source = manifest.get("source")
    if not isinstance(source, dict):
        _fail(manifest_path, "missing [source] block")
        failures += 1
        source = {}
    for field in REQUIRED_SOURCE:
        if not source.get(field):
            _fail(manifest_path, f"[source] missing: {field}")
            failures += 1

    kind = source.get("kind")
    if kind not in VALID_KINDS:
        _fail(manifest_path, f"[source].kind must be one of {sorted(VALID_KINDS)}; got {kind!r}")
        failures += 1
    elif kind == "port":
        for field in PORT_REQUIRED:
            if not source.get(field):
                _fail(manifest_path, f"[source] port pack missing: {field}")
                failures += 1

    skill_id = manifest.get("skill")
    if skill_id:
        skill_dir = pack_dir / "skills" / skill_id
        if not skill_dir.is_dir():
            _fail(pack_dir, f"skills/{skill_id}/ missing for declared skill={skill_id!r}")
            failures += 1
        else:
            validator = Path(__file__).resolve().parent / "validate_skill.py"
            res = subprocess.run(
                [sys.executable, str(validator), str(skill_dir)],
                capture_output=True, text=True,
            )
            if res.returncode != 0:
                sys.stderr.write(res.stderr)
                failures += 1
            if kind == "port":
                upstream_md = skill_dir / "upstream" / "SKILL.md"
                if not upstream_md.exists():
                    _fail(skill_dir, "port pack missing upstream/SKILL.md")
                    failures += 1

    if failures == 0:
        print(f"OK   {pack_dir}")
    return 0 if failures == 0 else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path, help="Pack directories to validate")
    args = parser.parse_args()

    rc = 0
    for path in args.paths:
        if not path.is_dir():
            print(f"FAIL {path}: not a directory", file=sys.stderr)
            rc = 1
            continue
        rc |= validate_pack(path)
    return rc


if __name__ == "__main__":
    sys.exit(main())
