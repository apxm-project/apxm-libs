# Authoring an `apxm-libs` pack

This guide walks through writing a new pack from a clean directory
to a tagged release. Read [`pack-format.md`](pack-format.md) first
if you have not already — this guide assumes you know what
`pack.toml`, `skill.toml`, and the three-layer hash chain are.

## 1. Scaffold the directory

```
packs/<pack-id>/
    pack.toml
    README.md
    skills/<skill-id>/
        skill.toml
        SKILL.md
        notes.md
```

For an original pack, set `pack.toml::[source].kind = "original"`
and `attribution = "APXM contributors."`. For a port, set
`kind = "port"` and fill `upstream`, `upstream_path`,
`upstream_commit`, `upstream_license` — the validator rejects a
port pack missing any of these, and `skills/<id>/upstream/SKILL.md`
must hold a verbatim copy of the source skill.

Start with empty `pack.toml::[integrity].pack_hash` and a missing
`skill.toml::artifact_hash`. Both are written by the build
command — never paste them by hand.

## 2. Validate the scaffold

```
python tools/validate_pack.py packs/<pack-id>
```

Without `--require-artifact`, the validator accepts a pack that
has no `skill.air` and no `skill.apxmobj` yet. This is the
authoring loop — write the manifest, validate, iterate.

## 3. Author the AIR graph

`skill.air` is the canonical IR for the skill. The Python frontend
(`apxm.contract`, `apxm.skill`) is the supported producer. A
decorator DSL emits canonical AIR JSON that the APXM compiler
ingests; raw hand-written AIR is supported but rare.

For port packs: read `upstream/SKILL.md`, identify the discrete
steps the skill performs, and translate each step into an AIR
node. Document the translation map in `notes.md` (one bullet per
upstream step → AIR node, with reasoning for any structural
divergence).

For original packs: `notes.md` documents the AIR-node design — why
each node exists, where shared-prefix or cohort groups apply, and
what the dispatch hints are.

## 4. Build the compiled artifact

```
dekk apxm libs build <pack-id>
```

This command:

1. Reads `[compile].opt_level` from `pack.toml` (default `O2`).
2. For each skill in `packs/<pack-id>/skills/`, invokes
   `apxm compile -O<n> --embed-manifest <skill.toml>
   <skill.air> -o <skill.apxmobj>`. The `--embed-manifest` flag
   stamps an `apxm.skill_manifest.v1` section into the artifact;
   the embedded copy has `artifact_hash` stripped.
3. Computes BLAKE3 of `skill.apxmobj` and writes
   `artifact_hash = "blake3:<hex>"` into the matching
   `skill.toml`.
4. Computes BLAKE3 of the resulting pack tarball and writes
   `pack_hash = "blake3:<hex>"` into `pack.toml::[integrity]`.

Running `libs build` twice on an unchanged pack produces
byte-identical `skill.apxmobj` and byte-identical `pack.toml` —
this is the O2 determinism contract. If your build outputs
diverge, that's a real bug (most often: a non-deterministic
Python frontend step). File it; do not work around it by pinning
hashes manually.

## 5. Verify with `--require-artifact`

```
python tools/validate_pack.py --require-artifact packs/<pack-id>
```

This mode rejects any pack whose skills lack a compiled artifact
or whose recorded `artifact_hash` doesn't match the bytes on
disk. Always run this before tagging a release; the
`libs publish` command runs it for you.

## 6. Pick an opt level

`O2` is the default and the right choice for nearly every pack.
It is:

- Byte-deterministic across rebuilds (the basis of the
  install-time tamper gate).
- Standard pipeline (canonicalize → CSE → DCE → schedule).

Set `[compile].opt_level = "O3"` in `pack.toml` only when:

- You have profiled the win on representative input.
- You have measured that the artifact is *still* deterministic
  on your machine (O3's `production()` config sets
  `verify: false`; APXM does not guarantee O3 determinism).
- You accept that some consumers may build from source on
  install if your O3 artifact does not reproduce in their
  environment.

If any of these is shaky, stay on `O2`.

## 7. Publish

```
dekk apxm libs publish <pack-id>
```

This re-runs `libs build`, runs the strict validator, and prints
the `gh release create <pack-id>-v<version> <tarball>` command for
you to execute. The publish step is operator-driven by design —
the maintainer holds the `gh` credentials, not the toolchain.

After the release lands, consumers can:

```
dekk apxm libs install <pack-id>==<version> --source github
```

## Per-pack documentation

Every pack ships:

- `pack.toml`, `skill.toml` (manifest schemas: see
  [`pack-format.md`](pack-format.md))
- `README.md` (pack-level intro)
- `SKILL.md` (what the skill does; when an agent should reach for
  it; declared `inputs`/`outputs` echoed in human prose)
- `notes.md` (translation map for ports / AIR-node design notes
  for originals)
- `upstream/SKILL.md` (port packs only: verbatim source)

A pack PR without `SKILL.md` or `notes.md` is rejected on review.
The plan does not survive without per-pack documentation — agents
choose between packs by reading these files, not the bytecode.
