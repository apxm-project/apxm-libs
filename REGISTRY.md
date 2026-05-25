# Pack registry

apxm-libs uses **GitHub Releases** as the v1 registry transport. Each
pack release publishes one tarball asset; consumers fetch it through
`dekk apxm libs install <pack-id>==<version> --source github` or by
sibling-clone of this repo.

## SemVer per pack

Every pack version is independent. `obra-superpowers-brainstorming
1.2.0` and `apxm-orient 0.3.0` follow their own cadence. Pack version
lives in `pack.toml::version` and must match the contained skill's
`skill.toml::version`.

- `0.x.y` — pack scaffold or pre-stable; `skill.air` may be absent or
  in flux.
- `x.y.z` (x ≥ 1) — pack is feature-complete (manifest, SKILL.md,
  `skill.air`, optional `skill.apxmobj`), and contract changes follow
  SemVer.

## Tarball layout

A release tarball for `<pack-id>-<version>.tar.gz` is the pack
directory **as-is**:

```
<pack-id>/
  pack.toml
  README.md
  skills/
    <skill-id>/
      skill.toml
      SKILL.md
      [skill.air]
      [skill.apxmobj]
      [notes.md, upstream/, ...]
  [shared/]
```

The top-level directory inside the tarball must be `<pack-id>` (not
`packs/<pack-id>` or `./`) so `dekk apxm libs install` can extract
and place it under `~/.apxm/libs/<pack-id>/` without renaming.

## pack_hash

`pack.toml::[integrity].pack_hash` carries the blake3 of the
canonical tarball. The publisher computes it with `dekk apxm libs
pack <pack-dir>`, pastes the result back into `pack.toml`, then
re-tars (the new pack.toml is now part of the tarball, so the
recorded hash describes the released bytes).

Consumer-side: `dekk apxm libs install --source github` recomputes
blake3 of the downloaded tarball and refuses to install on mismatch.
The same check is available post-install via `dekk apxm libs verify
<pack-id>`.

## Release flow (maintainer, manual)

GitHub Actions is deliberately not used (see the project's local-only
publishing posture). Each release is a deliberate human action.

```bash
# 1. Validate the pack you intend to release.
python3 tools/validate_pack.py packs/<pack-id>/

# 2. Build the tarball + compute pack_hash. Output goes to
#    packs/<pack-id>/../ by default; pass --out-dir to redirect.
dekk apxm libs pack packs/<pack-id>/

# 3. Paste the printed pack_hash into pack.toml [integrity].
#    Re-run `apxm libs pack` so the released tarball contains the
#    updated pack.toml. The second pack_hash is the canonical one.

# 4. Commit + tag. Tag pattern: <pack-id>-v<version>.
git add packs/<pack-id>/pack.toml
git commit -m "release(<pack-id>): v<version>"
git tag <pack-id>-v<version>
git push origin main <pack-id>-v<version>

# 5. Create the GitHub release with the tarball as an asset.
gh release create <pack-id>-v<version> \
  --title "<pack-id> v<version>" \
  --notes "See packs/<pack-id>/README.md" \
  packs/<pack-id>-<version>.tar.gz
```

## Yank / withdraw

Don't delete release assets — installs in the wild keep working from
sibling clones and from previously-downloaded tarballs, and silent
removal breaks reproducible builds.

Instead, mark the release as **pre-release** in GitHub and cut a new
release that supersedes it (`pack-id-v<version+0.0.1>` with a release
note pointing at the issue). The validator will start refusing the
old version on the next pack.toml-bump.

## Future: standalone registry

A purpose-built registry service is intentionally out of scope until
public submission volume warrants it. GitHub Releases is sufficient
through v1 because the install set is small (~25 packs), updates are
cadenced per-pack, and `gh` is already available in every contributor
environment.
