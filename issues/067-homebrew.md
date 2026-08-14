# 067 — Homebrew: `brew install klin`

**Status:** ✅ done (formula + CI + public tap [`homebrew-klin`](https://github.com/klin-lang/homebrew-klin) + tag `v0.1.0`)
**Depends on:** — (public releases unlock *stable*; HEAD works with repo access)

## Name

`klin` is **free** in homebrew-core (no formula/cask). Similar but different:
`kin`, `klim`.

## Delivered in repo

| Artifact | Meaning |
|---|---|
| [`Formula/klin.rb`](../Formula/klin.rb) | stable = Release tarball; HEAD = `dart compile exe` + `pkgshare` stdlib |
| [`.github/workflows/release.yml`](../.github/workflows/release.yml) | tag `v*` → macOS/Linux binaries + GitHub Release |
| [`docs/17-homebrew.md`](../docs/17-homebrew.md) | install / tap / sha256 |

Stdlib discovery for binary / Homebrew `share/klin`: `lib/project.dart`.

```sh
brew install klin-lang/klin/klin          # stable (prebuilt Release; no Dart)
brew install --HEAD klin-lang/klin/klin   # main (needs dart-lang/dart)
```

homebrew-core later.

`brew upgrade klin` = upgrade the **compiler**, not `.kl` packages
([066](066-klin-upgrade-outdated.md)).

## Checklist

- [x] `Formula/klin.rb` (HEAD + room for stable url/sha256)
- [x] release workflow on tag `v*`
- [x] stdlib next to install (pkgshare + search paths)
- [x] note + README
- [x] operator step: public repo + tag `v0.1.0` + fill in sha256 + tap [`homebrew-klin`](https://github.com/klin-lang/homebrew-klin)

## Out of scope

- PR to homebrew-core
- Windows (Homebrew is not the path; `task release` / scoop later)
