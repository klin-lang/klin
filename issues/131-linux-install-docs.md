# 131 — Linux install docs (tarball) + no apt/snap note

**Status:** 💭 planned (today: Linuxbrew or `.tar.gz`, undocumented for non-brew)
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
| Prebuilt `.tar.gz` from GitHub Release | ✅ exists, undocumented |
| From source (Dart `^3.5`) | ✅ `dart compile exe bin/klin.dart` |
| `apt` / `.deb` / `snap` | ❌ none (be explicit in docs) |

## Deliverable

- Docs section (README + [docs/17-homebrew.md](../docs/17-homebrew.md) or a
  rename to a general "install" page) with copy-paste tarball steps:
  ```sh
  curl -L -o klin.tar.gz \
    https://github.com/klin-lang/klin/releases/latest/download/klin-linux-amd64.tar.gz
  sha256sum -c klin-linux-amd64.sha256    # verify against Release sidecar
  tar -xzf klin.tar.gz                    # klin, stdlib/, templates/
  install -Dm755 klin ~/.local/bin/klin   # keep stdlib/ + templates/ beside it
  ```
- Make explicit: `stdlib/` and `templates/` must stay next to the binary (or in
  `share/klin/`), matching [`lib/project.dart`](../lib/project.dart) /
  [`lib/init.dart`](../lib/init.dart) discovery.
- Note: `klin run` needs a host C compiler (`gcc`/`clang`/`tcc`); `--emit-c`
  does not.
- Optional: a tiny `install.sh` (arch-detect amd64/arm64 → download latest →
  verify `.sha256` → drop into `~/.local/bin`) for a `curl … | sh` one-liner.

## Out of scope

- Actual `.deb` / PPA / snap packaging (larger, separate effort if demand
  appears).

## Criteria

- [ ] Linux tarball install documented (verify + layout + C compiler note).
- [ ] "no apt/snap" stated explicitly so users stop looking.
- [ ] (Optional) `install.sh` one-liner verified on x64 + arm64.
