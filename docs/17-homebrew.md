# Homebrew — installing the Klin compiler (issue 067)

`brew upgrade klin` = upgrade the **compiler**, not `.kl` packages
([066](../issues/066-klin-upgrade-outdated.md)).

## Status

- Public tap: [`klin-lang/homebrew-klin`](https://github.com/klin-lang/homebrew-klin)
  → `brew tap klin-lang/klin`
- Formula copy in this repo: [`Formula/klin.rb`](../Formula/klin.rb) (keep in sync)
- CI release on tag `v*`: [`.github/workflows/release.yml`](../.github/workflows/release.yml)
- Name `klin` free in homebrew-core; own tap first, core later

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

## Platforms in Release ([076](../issues/076-release-windows-arm.md))

On tag `v*` workflow builds 6 assets (`dart compile exe` per host — no
cross-compilation):

| Platform | Asset |
|---|---|
| macOS arm64 / x64 | `klin-macos-arm64.tar.gz` / `klin-macos-amd64.tar.gz` |
| Linux x64 / arm64 | `klin-linux-amd64.tar.gz` / `klin-linux-arm64.tar.gz` |
| Windows x64 / arm64 | `klin-windows-amd64.zip` / `klin-windows-arm64.zip` |

Each asset has `.sha256`. Homebrew covers macOS/Linux; Windows for now via
`.zip` from Release (Scoop/WinGet — future). On Windows host C compiler for
`klin run` is MSVC / clang / mingw.

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
