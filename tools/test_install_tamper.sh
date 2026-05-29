#!/usr/bin/env bash
# End-to-end install + tamper test for an apxm-libs pack.
#
# Exercises the three hash layers (tarball pack_hash, per-skill
# artifact_hash, wire-internal BLAKE3) by:
#   0. Building the pack so pack.toml [integrity].pack_hash and each
#      skill.toml artifact_hash are POPULATED (a dev pack ships them
#      empty; an empty pack_hash makes --strict verify fail hard and
#      would make the tamper assertions below unreachable — see F09).
#   1. Installing a pack from a freshly-built tarball.
#   2. Verifying with --strict — must pass (hash is now populated).
#   3. Tampering one byte of the installed skill.apxmobj.
#   4. Re-verifying — must fail with the canonical
#      (pack_id, skill_id, expected, actual) mismatch tuple.
#   5. Restoring the pack and removing it.
#
# Why --strict: with an empty/missing pack_hash the verifier fails OPEN
# in its non-strict default (it only WARNS and falls back to per-skill
# checks). This test seals the pack first and then asserts under
# --strict so the real tamper-detection path is exercised end to end.
#
# The test does NOT depend on a network release: it uses sibling-clone
# install (the default `dekk apxm libs install <pack-id>` path) so the
# only inputs are a built pack under packs/<pack-id>/ and a working
# dekk + apxm clone.
#
# Exit 0 on full pass; 1 on any deviation. Intermediate output is
# written to a temp dir under .apxm/ which is cleaned up on success.
#
# Usage:
#   tools/test_install_tamper.sh <pack-id>
#
# Required env:
#   APXM_REPO  — path to the apxm clone that owns `dekk apxm libs`.
#                Defaults to ../apxm relative to this script.
#   APXM_LIBS_ROOT — install root; default ~/.apxm/libs.

set -euo pipefail

pack_id="${1:-}"
if [[ -z "$pack_id" ]]; then
  echo "usage: $0 <pack-id>" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
libs_root="$(cd "$script_dir/.." && pwd)"
apxm_repo="${APXM_REPO:-$(cd "$libs_root/../apxm" && pwd)}"
install_root="${APXM_LIBS_ROOT:-$HOME/.apxm/libs}"
pack_dir="$libs_root/packs/$pack_id"

if [[ ! -d "$pack_dir" ]]; then
  echo "FAIL: pack source not found: $pack_dir" >&2
  exit 1
fi
if [[ ! -d "$apxm_repo" ]]; then
  echo "FAIL: apxm clone not found at $apxm_repo (set APXM_REPO)" >&2
  exit 1
fi

dekk() {
  (cd "$apxm_repo" && command dekk "$@")
}

skill_id="$(python3 -c '
import sys, tomllib
print(tomllib.loads(open(sys.argv[1]).read()).get("skill", ""))
' "$pack_dir/pack.toml")"

if [[ -z "$skill_id" ]]; then
  echo "FAIL: pack.toml does not declare skill" >&2
  exit 1
fi

apxmobj="$install_root/$pack_id/skills/$skill_id/skill.apxmobj"

step() { printf '\n=== %s ===\n' "$*"; }

step "0. uninstall any prior copy"
dekk apxm libs uninstall "$pack_id" 2>/dev/null || true

step "1. build pack (populate pack_hash + artifact_hash + apxmobj)"
# Without this the source pack ships pack_hash="" and verify --strict
# would abort before reaching the tamper path (F09).
dekk apxm libs build "$pack_id"

pack_hash="$(python3 -c '
import sys, tomllib
m = tomllib.loads(open(sys.argv[1]).read())
print((m.get("integrity") or {}).get("pack_hash") or "")
' "$pack_dir/pack.toml")"
if [[ -z "$pack_hash" ]]; then
  echo "FAIL: build did not populate pack.toml [integrity].pack_hash" >&2
  exit 1
fi

step "2. install from sibling clone"
dekk apxm libs install "$pack_id"

if [[ ! -f "$apxmobj" ]]; then
  echo "FAIL: install did not produce $apxmobj" >&2
  exit 1
fi

step "3. verify --strict (must pass; hash is populated)"
dekk apxm libs verify --strict "$pack_id"

step "4. tamper one byte of skill.apxmobj"
backup="$(mktemp)"
cp "$apxmobj" "$backup"
# Flip one bit deep in the artifact (avoid the header so the read
# path gets far enough to recompute the BLAKE3 before failing).
python3 - "$apxmobj" <<'PY'
import os, sys
p = sys.argv[1]
data = bytearray(open(p, "rb").read())
target = max(64, len(data) // 2)
data[target] ^= 0x01
open(p, "wb").write(bytes(data))
print(f"tampered byte {target} of {len(data)}")
PY

step "5. verify --strict (must FAIL with canonical mismatch tuple)"
if out=$(dekk apxm libs verify --strict "$pack_id" 2>&1); then
  echo "FAIL: verify accepted tampered pack" >&2
  echo "$out" >&2
  cp "$backup" "$apxmobj"
  rm -f "$backup"
  exit 1
fi

# Expect a line of the form:
#   pack=<id> skill=<id> expected=blake3:... actual=blake3:...
if ! grep -E "pack=$pack_id\s+skill=$skill_id\s+expected=blake3:\S+\s+actual=blake3:\S+" <<<"$out" >/dev/null; then
  echo "FAIL: tamper-detection error did not carry canonical tuple" >&2
  echo "got:" >&2
  echo "$out" >&2
  cp "$backup" "$apxmobj"
  rm -f "$backup"
  exit 1
fi
echo "OK: tamper detected with canonical (pack_id, skill_id, expected, actual) tuple"

step "6. restore + cleanup"
cp "$backup" "$apxmobj"
rm -f "$backup"
dekk apxm libs verify --strict "$pack_id"
dekk apxm libs uninstall "$pack_id"

echo
echo "PASS: install + tamper end-to-end for $pack_id"
