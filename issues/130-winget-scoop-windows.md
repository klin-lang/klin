# 130 — Windows package channels: WinGet + Scoop

**Status:** 💭 planned (today: `.zip` from Release only)
**Depends on:** [076](076-release-windows-arm.md), [067](067-homebrew.md)

## Goal

Give Windows users a one-command install like `brew install klin` on
macOS/Linux. Homebrew is not a Windows path ([067](067-homebrew.md) out of
scope; [076](076-release-windows-arm.md) marks Scoop/WinGet as *future*), so
add the two native Windows channels:

- **WinGet** — `winget install klin-lang.klin`
- **Scoop** — `scoop bucket add klin … ; scoop install klin`

Both wrap the existing prebuilt `.zip` assets already produced on tag `v*`
(`klin-windows-amd64.zip` / `klin-windows-arm64.zip`, each with `.sha256`) — no
new build work, only packaging manifests + docs.

## WinGet

- Manifest set (`installer` + `locale` + `version`) under
  `klin-lang.klin` in the community
  [`microsoft/winget-pkgs`](https://github.com/microsoft/winget-pkgs) repo.
- `InstallerType: zip` with a nested portable `klin.exe`; declare `stdlib\` and
  `templates\` are unpacked next to the binary (must stay beside `klin.exe`,
  same discovery as [`lib/project.dart`](../lib/project.dart)).
- `InstallerSha256` = the `.sha256` already published on the Release.
- Per-arch installer entries (x64 + arm64) from the two `.zip` assets.
- Submitting to `winget-pkgs` is a maintainer action (PR + CI validation);
  agent prepares the manifest, not the upstream PR.

## Scoop

- App manifest `klin.json` (`version`, `architecture.64bit`/`arm64` `url` +
  `hash`, `bin: "klin.exe"`, `extract_dir`) pointing at the Release `.zip`.
- Host in a bucket repo (e.g. `klin-lang/scoop-klin`) mirroring the Homebrew tap
  pattern; keep a copy in this repo for review like `Formula/klin.rb`.
- `checkver` + `autoupdate` blocks so new tags bump the manifest automatically.

## Release automation (optional, later)

On tag `v*` ([release.yml](../.github/workflows/release.yml)) after
`publish`: emit/refresh the WinGet + Scoop manifests from the freshly uploaded
`.zip` + `.sha256` (like the Homebrew `sha256` auto-fill idea in
[076](076-release-windows-arm.md)).

## Note

Installs the Klin **frontend** only; `klin run` still needs a host C compiler
on `PATH` (MSVC / clang / mingw on Windows). `--emit-c` does not.

## Criteria

- [ ] Scoop manifest `klin.json` (x64 + arm64, hashes from Release) in repo +
      bucket repo.
- [ ] WinGet manifest set for `klin-lang.klin` (x64 + arm64) prepared.
- [ ] Docs: Windows install via WinGet/Scoop in
      [docs/17-homebrew.md](../docs/17-homebrew.md) (or a rename) + README.
- [ ] `winget install` / `scoop install` yield a working `klin --version`.
