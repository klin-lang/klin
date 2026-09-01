# AGENTS.md

Klin is a systems language compiled to C. The compiler is written in Dart
(`bin/klin.dart`, `lib/`). **Language surface** (what is in `.kl`, what is
a library, what not to propose): `docs/language.md`. Landing and idea:
`README.md`, `docs/00-idea.md`. Tutorial: `docs/guide.md`. Doc map:
`docs/README.md`. CLI: `docs/06-cli.md`, `Taskfile.yml`. Rules: `CLAUDE.md`.
Generics are `$fn`, not `[T]` in the compiler.

Committed text in this repo and `klin-lang/*` packages is **English only**
(docs, issues, comments, commits, PRs). See `CLAUDE.md`.

## Cursor Cloud specific instructions

Single Dart package — there is no separate frontend/backend to start; the
"application" is the `klin` CLI compiler, run in dev with `dart run bin/klin.dart …`.

Toolchain already provisioned in the VM image (do not reinstall in the update
script): the Dart SDK lives at `/usr/lib/dart` and is symlinked onto `PATH` via
`/usr/local/bin/dart`. `gcc` and `clang` are installed; `tcc` is not in the
base image (CI installs `tcc` for faster e2e goldens). The startup update
script only runs `dart pub get`.

Common commands (all from the repo root):
- Lint: `dart analyze` (CI's required `test` job runs `dart analyze` then tests).
- Tests: `dart test` (CI runs `--tags unit`, builds `build/klin`, then
  `--tags e2e` with `KLIN_E2E_BIN`, each with `--concurrency=$(nproc)`).
  Pipeline coverage: `test/pipeline_*_test.dart` (`unit` = frontend only;
  `e2e` = host CC + Klin CLI; optional `--exclude-tags e2e_net` skips
  network `klin get`). Goldens use `tcc` when on `PATH` (`KLIN_CC` overrides).
  Local fast loop: `dart test --tags unit`. Full: `dart test`.
- Run a program end-to-end: `dart run bin/klin.dart run examples/hello.kl`
  (parse → check → emit C → compile with host `cc` → execute).
- Inspect generated C without running: `dart run bin/klin.dart --emit-c <file.kl>`.

Non-obvious notes:
- `klin run` and `klin test` require a host C compiler (`gcc`/`clang`/`tcc`) on
  `PATH`; pure `--emit-c` does not.
- Generated C is written under `out/` (and `examples/**/out/`), which is
  gitignored — safe to leave behind.
