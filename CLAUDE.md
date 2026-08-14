# Klin

A systems language compiled to C. The backend produces one readable `.c` file,
then uses gcc, clang, or tcc. The compiler is written in Dart.

The project context, decisions, architecture, and roadmap are English design
documents. Map: @docs/README.md.

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
