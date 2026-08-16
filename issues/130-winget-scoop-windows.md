# 130 — Windows package channels: WinGet + Scoop

**Status:** 🔨 Scoop ✅ live ([`klin-lang/scoop-klin`](https://github.com/klin-lang/scoop-klin)); WinGet manifests prepared in-repo (upstream `winget-pkgs` submit still maintainer)
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
  `klin-lang.klin` — prepared in-repo at
  [`winget/manifests/k/klin-lang/klin/`](../winget/manifests/k/klin-lang/klin/)
  for copy into the community
  [`microsoft/winget-pkgs`](https://github.com/microsoft/winget-pkgs) repo.
- `InstallerType: zip` with a nested portable `klin.exe`; declare `stdlib\` and
  `templates\` are unpacked next to the binary (must stay beside `klin.exe`,
  same discovery as [`lib/project.dart`](../lib/project.dart)).
- `InstallerSha256` = the `.sha256` already published on the Release.
- Per-arch installer entries (x64 + arm64) from the two `.zip` assets.
- Submitting to `winget-pkgs` is a maintainer action (PR + CI validation);
  agent prepares the manifest, not the upstream PR.

### WinGet manifests (in this repo)

Prepared under
[`winget/manifests/k/klin-lang/klin/0.1.3/`](../winget/manifests/k/klin-lang/klin/0.1.3/)
for `PackageIdentifier: klin-lang.klin` (x64 + arm64, SHA256 from Release
`v0.1.3` sidecars). Copy that folder into `microsoft/winget-pkgs` when
submitting.

### Maintainer submit checklist (Windows only)

`winget` / `wingetcreate` do **not** run on macOS or Linux. Do this when you
have a Windows machine (or VM). Manifests for `0.1.3` are already in this
repo — you do **not** need `wingetcreate new` for the first publish.

Prereq: GitHub account that can fork
[`microsoft/winget-pkgs`](https://github.com/microsoft/winget-pkgs), plus a
[PAT](https://github.com/settings/tokens) with `public_repo` (for
`wingetcreate submit`).

#### A — preferred: submit prepared manifests

```powershell
# 1. Tools
winget install Microsoft.WingetCreate

# 2. Clone Klin (or use an existing checkout on main)
git clone https://github.com/klin-lang/klin.git
cd klin\winget\manifests\k\klin-lang\klin\0.1.3

# 3. Validate + optional local install smoke test
winget validate --manifest .
winget install --manifest .
klin --version

# 4. Open PR to microsoft/winget-pkgs (forks + pushes for you)
wingetcreate submit --token <PAT> .
```

Microsoft CI + moderators merge. Only then does public install work:

```powershell
winget install klin-lang.klin
```

#### B — manual PR (no wingetcreate submit)

1. Fork [`microsoft/winget-pkgs`](https://github.com/microsoft/winget-pkgs).
2. Copy this repo’s
   [`winget/manifests/k/klin-lang/klin/0.1.3/`](../winget/manifests/k/klin-lang/klin/0.1.3/)
   into the same path in the fork (`manifests/k/klin-lang/klin/0.1.3/`).
3. Commit + open a PR (title e.g. `New package: klin-lang.klin version 0.1.3`).

#### C — later versions (after first merge)

```powershell
wingetcreate update klin-lang.klin --version X.Y.Z `
  --urls https://github.com/klin-lang/klin/releases/download/vX.Y.Z/klin-windows-amd64.zip `
         https://github.com/klin-lang/klin/releases/download/vX.Y.Z/klin-windows-arm64.zip
wingetcreate submit --token <PAT>
```

Or bump the YAML under `winget/manifests/…` in this repo (SHA256 from the
Release `.sha256` sidecars — never hand-compute), then submit again.

#### Regenerating from scratch (only if needed)

```powershell
wingetcreate new https://github.com/klin-lang/klin/releases/download/vX.Y.Z/klin-windows-amd64.zip
```

Shape must stay `InstallerType: zip` + nested portable `klin.exe` (x64 +
arm64); `stdlib\` and `templates\` stay beside the exe (see
[`lib/project.dart`](../lib/project.dart)).

Gotcha: `klin run` still needs a host C compiler (MSVC/clang/mingw);
`--emit-c` does not.

## Scoop — ✅ done

Live bucket: [`klin-lang/scoop-klin`](https://github.com/klin-lang/scoop-klin)
(`bucket/klin.json`).

```powershell
scoop bucket add klin https://github.com/klin-lang/scoop-klin
scoop install klin
```

- App manifest `klin.json` (`version`, `architecture.64bit`/`arm64` `url` +
  `hash`, `bin: "klin.exe"`) points at the Release `.zip` (`stdlib\` +
  `templates\` sit beside `klin.exe` at the archive root, so no `extract_dir`).
- `checkver` + `autoupdate` blocks bump `version` / `url` / `hash` from the
  Release `.sha256` sidecars on each new tag.
- Manifest verified as valid JSON with reachable asset URLs (`v0.1.3`, x64 +
  arm64); an end-to-end `scoop install` on a Windows host is still pending.

## Release automation (optional, later)

On tag `v*` ([release.yml](../.github/workflows/release.yml)) after
`publish`: emit/refresh the WinGet + Scoop manifests from the freshly uploaded
`.zip` + `.sha256` (like the Homebrew `sha256` auto-fill idea in
[076](076-release-windows-arm.md)).

## Note

Installs the Klin **frontend** only; `klin run` still needs a host C compiler
on `PATH` (MSVC / clang / mingw on Windows). `--emit-c` does not.

## Criteria

- [x] Scoop manifest `klin.json` (x64 + arm64, hashes from Release) in bucket
      repo [`klin-lang/scoop-klin`](https://github.com/klin-lang/scoop-klin).
- [x] WinGet manifest set for `klin-lang.klin` (x64 + arm64) prepared in
      [`winget/manifests/k/klin-lang/klin/0.1.3/`](../winget/manifests/k/klin-lang/klin/0.1.3/).
- [x] Docs: Scoop + WinGet install in
      [docs/17-homebrew.md](../docs/17-homebrew.md) + README.
- [ ] `winget install` / `scoop install` yield a working `klin --version`
      (Scoop manifest validated: valid JSON + reachable URLs; WinGet pending
      upstream merge to `microsoft/winget-pkgs`; Windows run pending).
