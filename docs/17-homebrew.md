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

Requires [Dart tap](https://github.com/dart-lang/homebrew-dart) to build from source.

Homebrew **6+** [tap trust](https://docs.brew.sh/Tap-Trust): third-party taps
are not loaded until you trust a formula (or the whole tap). Prefer
`brew trust --formula …` over `brew trust <tap>`. Klin’s build dep is
`dart-lang/dart/dart` — without trusting it, `brew install` fails with
“Refusing to load formula … from untrusted tap”.

Short form — Homebrew adds the Klin tap automatically:

```sh
brew tap dart-lang/dart
brew trust --formula dart-lang/dart/dart
brew install klin-lang/klin/klin
klin --version
```

Equivalent explicit taps (short name `klin` also needs trust):

```sh
brew tap dart-lang/dart
brew trust --formula dart-lang/dart/dart
brew tap klin-lang/klin
brew trust --formula klin-lang/klin/klin
brew install klin
```

HEAD (`main`):

```sh
brew install --HEAD klin-lang/klin/klin
# or, after `brew tap klin-lang/klin`:
brew install --HEAD klin
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
2. Compute source sha:

```sh
curl -sL \
  "https://github.com/klin-lang/klin/archive/refs/tags/vX.Y.Z.tar.gz" \
  | shasum -a 256
```

3. Update `url` / `sha256` / `version` in **both**:
   - [`Formula/klin.rb`](../Formula/klin.rb) (this repo)
   - [`klin-lang/homebrew-klin`](https://github.com/klin-lang/homebrew-klin) `Formula/klin.rb`

## Install from clone (no tap)

```sh
brew tap dart-lang/dart
brew install --formula Formula/klin.rb          # stable (tag in formula)
brew install --HEAD --formula Formula/klin.rb   # main
```

## Install layout

- `bin/klin` — AOT (`dart compile exe`)
- `share/klin/stdlib/` — stdlib (`pkgshare`); compiler also looks for `stdlib/`
  next to binary ([`lib/project.dart`](../lib/project.dart))
- `share/klin/templates/` — MCU scaffolds for `klin init` (`pkgshare`); same
  discovery as stdlib ([`lib/init.dart`](../lib/init.dart), [075](../issues/075-board-pack-init-host.md))

Host `gcc` / `clang` / `tcc` still required for `klin run`.
