# 116 — Documentation map: landing, idea, guide

**Status:** ✅ done
**Depends on:** [036](036-docs-catchup.md), [082](082-english-issues-docs.md), [023](023-examples.md)

## Problem

After 025 / 082 / 115 the corpus is English, but the *shape* is still a
notes pile:

- `README.md` is a feature changelog, not a landing page
- `docs/00-idea.md` reads as “STM32 language” (the first proof, not the bet)
- there is no short path that teaches someone to write Klin
- `docs/` is numbered by when a note was written, not by who should read it
- `issues/` is the work queue, not a user manual
- `note/` is already `docs/` (082) — do not bring it back

## Roles (locked)

| Place | Role |
|---|---|
| `README.md` | Landing: what / why / who / 30-second start / links |
| `docs/README.md` | Map of the docs |
| `docs/00-idea.md` | Founding idea (principle, C backend, neighbors) |
| `docs/01-decisions.md` | Decision log D1–D9 |
| `docs/02-architecture.md` | Compiler rules (Z1–Z6) |
| `docs/guide.md` | Short language tutorial (not a full spec) |
| `docs/language.md` | `.kl` contract — what is language vs library vs not Klin ([133](133-docs-language-surface.md)) |
| `docs/03+` | Feature and tooling notes |
| `issues/` | Roadmap — what compiles next |
| `examples/` | Runnable demos |

## Done

- [x] Rewrite README as a landing page (no feature dump)
- [x] Rewrite `00-idea.md`: host + any C target; C exit hatch; neighbors
- [x] Add `docs/README.md` (reader map)
- [x] Add `docs/guide.md` (hello → mut → `!T` → C)
- [x] Point CLAUDE / examples / 023 / 036 at the new map
- [x] Fix leftover `note/…` comments in examples

## Out of scope

- Full language reference / grammar spec
- Renaming numbered `docs/04+` slugs
- Translating or merging `issues/` into user docs
- New language features
