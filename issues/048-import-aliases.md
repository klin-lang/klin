# 048 — Import aliases (+ local string)

**Status:** ✅ done (`import geom oso`, `import "path" [alias]`)
**Depends on:** [006](006-modules.md), [047](047-directory-modules.md)

## Context

Today: `import geom` — qualifier = ident. Partial alias already exists
(`import file_a` with `module real` → use `file_a.…`, mangling `real_`).
No explicit rename and no `import "…"`.

## Proposed syntax

```klin
import geom oso                      // local alias: qualifier = oso
import "path/to/osa"                 // string; default qualifier = last segment
import "path/to/osa" oso             // string + alias
```

Path resolution as in 020/047 (`lib/`, `-I`, `KLIN_PATH`, file or directory).
`pub` / private unchanged.

## MVP scope (done)

- parser: optional alias after `import` (ident or string) ✅
- `import "relative/path" [alias]` **locally** (no network) ✅
- tests + note in [docs/11](../docs/11-klin-libraries.md) ✅

Implementation: qualifier (alias or default = last segment) keys
`importAliases` and is used in source; C mangling uses the real
`module` name. Alias collision and alias being a C keyword are rejected.
`ImportSpec` node in `lib/ast.dart`, parsing in `lib/parser.dart`
(`_importSpec`), resolution/keying in `lib/project.dart`, round-trip in
`lib/fmt.dart`. Tests in `test/pipeline_*_test.dart` (issue 048).

## Out of scope

- fetch from GitHub / remote → [049](049-remote-imports.md)
- package manager / lockfile
- SVD/IOC artifacts (`import "*.svd"`) → [053](053-device-board-assets.md)
