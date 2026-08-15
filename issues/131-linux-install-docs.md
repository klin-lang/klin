# 131 — Linux install docs (tarball) + no apt/snap note

**Status:** ✅ done  
**Depends on:** [076](076-release-windows-arm.md), [067](067-homebrew.md)

## Goal

Document a first-class Linux install that does **not** require Homebrew, and
state plainly that there is currently no `apt`/`.deb` or `snap` package. The
prebuilt `.tar.gz` assets already exist on tag `v*`
(`klin-linux-amd64.tar.gz` / `klin-linux-arm64.tar.gz`, each with `.sha256`) —
this is docs + a small helper, not new build work.

## Channels on Linux (today)

| Channel | Status |
|---|---|
| Homebrew on Linux (Linuxbrew) | ✅ `brew install klin-lang/klin/klin` |
| Prebuilt `.tar.gz` from GitHub Release | ✅ documented + [`scripts/install-linux.sh`](../scripts/install-linux.sh) |
| From source (Dart `^3.5`) | ✅ `dart compile exe bin/klin.dart` |
| `apt` / `.deb` / `snap` | ❌ none (stated in docs) |

## Done

- [x] Linux tarball install documented (verify + layout + C compiler note) —
      [docs/17-homebrew.md](../docs/17-homebrew.md), [README.md](../README.md)
- [x] "no apt/snap" stated explicitly
- [x] [`scripts/install-linux.sh`](../scripts/install-linux.sh) — arch-detect,
      download latest, `sha256sum -c`, install under `~/.local/lib/klin` +
      symlink `~/.local/bin/klin` (stdlib/templates beside the binary)

## Out of scope

- Actual `.deb` / PPA / snap packaging (larger, separate effort if demand
  appears).
