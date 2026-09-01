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
`/usr/local/bin/dart`. `gcc` and `clang` are installed; `tcc` is not. The startup
update script only runs `dart pub get`.

Common commands (all from the repo root):
- Lint: `dart analyze` (CI's required `test` job runs `dart analyze` then `dart test`).
- Tests: `dart test` (CI runs `--tags unit` then `--tags e2e`, each with
  `--concurrency=$(nproc)`). Pipeline coverage lives in
  `test/pipeline_*_test.dart` (`unit` = frontend only; `e2e` shells out to
  `gcc` / `dart run bin/klin.dart`, so a host C compiler must be on `PATH`).
  Local fast loop: `dart test --tags unit`. Full: `dart test`.
- Run a program end-to-end: `dart run bin/klin.dart run examples/hello.kl`
  (parse → check → emit C → compile with host `cc` → execute).
- Inspect generated C without running: `dart run bin/klin.dart --emit-c <file.kl>`.

Non-obvious notes:
- `klin run` and `klin test` require a host C compiler (`gcc`/`clang`) on `PATH`;
  pure `--emit-c` does not.
- Generated C is written under `out/` (and `examples/**/out/`), which is
  gitignored — safe to leave behind.
