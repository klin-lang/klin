# Installing Klin (Homebrew, Scoop, Linux tarball)

`brew upgrade klin` = upgrade the **compiler**, not `.kl` packages
([066](../issues/066-klin-upgrade-outdated.md)).

Issue: [067](../issues/067-homebrew.md) (Homebrew), [130](../issues/130-winget-scoop-windows.md)
(Scoop / WinGet), [131](../issues/131-linux-install-docs.md) (Linux tarball).

## Status

- Public tap: [`klin-lang/homebrew-klin`](https://github.com/klin-lang/homebrew-klin)
  → `brew tap klin-lang/klin`
- Formula copy in this repo: [`Formula/klin.rb`](../Formula/klin.rb) (keep in sync)
- CI release on tag `v*`: [`.github/workflows/release.yml`](../.github/workflows/release.yml)
- Name `klin` free in homebrew-core; own tap first, core later
- **No `apt` / `.deb` / `snap` package** — use Homebrew on Linux, the
  Release `.tar.gz` below, or build from source. Do not look for a PPA.

## Install (recommended)

**Stable** downloads the prebuilt binary from the GitHub Release
(`klin-macos-*` / `klin-linux-*`). **No Dart** and no `dart-lang/dart` tap.

Short form — Homebrew adds the tap automatically and trusts that formula:

```sh
brew install klin-lang/klin/klin
klin --version
```

Equivalent explicit taps (Homebrew 6+ [tap trust](https://docs.brew.sh/Tap-Trust)
if the short name is refused):

```sh
brew tap klin-lang/klin
brew trust --formula klin-lang/klin/klin
brew install klin
```

HEAD (`main`) still compiles from source — needs
[Dart tap](https://github.com/dart-lang/homebrew-dart):

```sh
brew tap dart-lang/dart
brew trust --formula dart-lang/dart/dart
brew install --HEAD klin-lang/klin/klin
```

Upgrade:

```sh
brew upgrade klin
```

## macOS Command Line Tools

Homebrew itself needs a current **Xcode Command Line Tools** (CLT) install,
even when the formula only downloads the **prebuilt** Klin binary (no Dart).
This is Apple / Homebrew, not a Klin or Dart requirement.

On a new macOS (e.g. **macOS 26**) `brew install` can fail with:

```text
Error: Your Command Line Tools (CLT) does not support macOS 26.
You have 16.x.x.
Update them from Software Update or run:
  softwareupdate --all --install --force
If that doesn't show you an update, run:
  sudo rm -rf /Library/Developer/CommandLineTools
  sudo xcode-select --install
```

Or install the CLT package that matches the OS (e.g. **Command Line Tools
for Xcode 26.3**) from Software Update / Apple Developer, then retry
`brew install klin-lang/klin/klin`.

`klin run` still needs a host C compiler on `PATH` (`clang` from CLT is
enough). `--emit-c` does not.

## Platforms in Release ([076](../issues/076-release-windows-arm.md))

On tag `v*` workflow builds 6 assets (`dart compile exe` per host — no
cross-compilation):

| Platform | Asset |
|---|---|
| macOS arm64 / x64 | `klin-macos-arm64.tar.gz` / `klin-macos-amd64.tar.gz` |
| Linux x64 / arm64 | `klin-linux-amd64.tar.gz` / `klin-linux-arm64.tar.gz` |
| Windows x64 / arm64 | `klin-windows-amd64.zip` / `klin-windows-arm64.zip` |

Each asset has `.sha256`. Homebrew covers macOS/Linux; Windows via **Scoop**
(below) or the raw `.zip` from Release (WinGet — future, see
[130](../issues/130-winget-scoop-windows.md)). On Windows the host C compiler
for `klin run` is MSVC / clang / mingw.

## Linux (Release tarball, no Homebrew)

Prebuilt, no Dart. Same assets Homebrew uses on Linux
(`klin-linux-amd64.tar.gz` / `klin-linux-arm64.tar.gz` + `.sha256`).

**There is no `apt`, `.deb`, or `snap` package.** Use this tarball, Linuxbrew
(`brew install klin-lang/klin/klin` above), or build from source.

The archive layout is `klin`, `stdlib/`, `templates/` at the top level. Keep
`stdlib/` and `templates/` **beside the binary** (or under `share/klin/` next
to an install prefix) so discovery in [`lib/project.dart`](../lib/project.dart)
/ [`lib/init.dart`](../lib/init.dart) finds them — same rule as Homebrew
`pkgshare`.

### One-liner ([`scripts/install-linux.sh`](../scripts/install-linux.sh))

```sh
curl -fsSL https://raw.githubusercontent.com/klin-lang/klin/main/scripts/install-linux.sh | bash
```

Installs into `~/.local/lib/klin/` (binary + `stdlib/` + `templates/`) and
symlinks `~/.local/bin/klin`. Override with `KLIN_PREFIX=/opt/klin` if needed.
Ensure `~/.local/bin` is on `PATH`.

### Manual steps (amd64)

```sh
mkdir -p ~/.local/lib/klin ~/.local/bin
cd ~/.local/lib/klin
curl -fsSL -O https://github.com/klin-lang/klin/releases/latest/download/klin-linux-amd64.tar.gz
curl -fsSL -O https://github.com/klin-lang/klin/releases/latest/download/klin-linux-amd64.sha256
sha256sum -c klin-linux-amd64.sha256
tar -xzf klin-linux-amd64.tar.gz          # klin, stdlib/, templates/
ln -sfn "$PWD/klin" ~/.local/bin/klin
klin --version
```

For arm64, replace `amd64` with `arm64` (`uname -m` → `aarch64`).

`klin run` still needs a host C compiler on `PATH` (`gcc` / `clang` / `tcc`);
`--emit-c` does not.

## Windows (Scoop)

Prebuilt, no Dart. Bucket: [`klin-lang/scoop-klin`](https://github.com/klin-lang/scoop-klin)
(wraps the `klin-windows-*.zip` Release assets; `stdlib\` + `templates\` ship
beside `klin.exe`).

```powershell
scoop bucket add klin https://github.com/klin-lang/scoop-klin
scoop install klin
klin --version
```

Upgrade after a new `v*` release (the manifest auto-updates via
`checkver` / `autoupdate`):

```powershell
scoop update klin
```

`klin run` still needs a host C compiler on `PATH` (MSVC / clang / mingw);
`--emit-c` does not.

## Releasing a new stable formula

1. Push tag `vX.Y.Z` on `klin` → `release` workflow publishes binaries
2. Copy each platform `.sha256` from the Release into **both** formulas
   (`on_macos` / `on_linux` `url` + `sha256` + `version`):
   - [`Formula/klin.rb`](../Formula/klin.rb) (this repo)
   - [`klin-lang/homebrew-klin`](https://github.com/klin-lang/homebrew-klin) `Formula/klin.rb`

```sh
# example
curl -sL \
  "https://github.com/klin-lang/klin/releases/download/vX.Y.Z/klin-macos-arm64.sha256"
```

## Install from clone (no tap)

```sh
brew install --formula Formula/klin.rb          # stable (Release tarball)
brew install --HEAD --formula Formula/klin.rb   # main (needs Dart tap)
```

## Install layout

- `bin/klin` — AOT binary (Release tarball; HEAD uses `dart compile exe`)
- `share/klin/stdlib/` — stdlib (`pkgshare`); compiler also looks for `stdlib/`
  next to binary ([`lib/project.dart`](../lib/project.dart))
- `share/klin/templates/` — MCU scaffolds for `klin init` (`pkgshare`); same
  discovery as stdlib ([`lib/init.dart`](../lib/init.dart), [075](../issues/075-board-pack-init-host.md))

Host `gcc` / `clang` / `tcc` still required for `klin run`.
