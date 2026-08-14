# Klin

A systems language compiled to C. The backend produces one readable `.c` file,
then uses gcc, clang, or tcc. The compiler is written in Dart.

The project context, decisions, architecture, and roadmap are English design
documents. Map: @docs/README.md.

**Language:** everything committed in Klin repos (`klin` and `klin-lang/*`)
is English — `docs/`, `issues/`, README, comments, diagnostics, commit
messages, PR titles and bodies. No bilingual PL+EN mirror
([025](issues/025-english-project.md), [082](issues/082-english-issues-docs.md),
[115](issues/115-english-leftover-pl.md)). Chat with a human may use another
language; the tree stays English.

- Landing / why: @README.md, @docs/00-idea.md
- Language tutorial: @docs/guide.md
- Design decisions: @docs/01-decisions.md
- Architecture and rules: @docs/02-architecture.md
- Roadmap: @issues/sorted.md

## Rules that always apply

- Primary rule: no hidden allocation, no hidden control flow, and no hidden
  cost. If a feature does not disappear in C emission, it likely violates this
  rule.
- Use a hand-written recursive-descent parser. Do not propose parser
  generators.
- Every token carries a source position (line and column). Emission includes
  `#line`.
- The frontend catches every error; gcc must never report an error in generated
  code.
- Do not expand the scope of the current step in `issues/sorted.md`.
- Feature workflow (always): sync/`checkout` from `origin/main` → new branch → implement (code + tests) → update docs (`docs/`, `issues/`, README/stdlib README as needed) and `examples/` → push + PR → skill `rcfix` (Bugbot, fixes, scoreboard). Never commit on `main`/`develop`.
- Skill `pmain` (`.cursor/skills/pmain/SKILL.md`): shorthand for "sync main" — `git checkout main && git pull origin main` (update only; never work/commit on `main`).
- Skill `rmain` (`.cursor/skills/rmain/SKILL.md`): shorthand for "rebase a PR on main" — no number = newest open PR; `rmain 267` = that PR. Fetch `origin/main`, rebase the PR head, `--force-with-lease`. Never rebase `main`/`develop`.
