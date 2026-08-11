# Klin libraries (issues 020 / 047)

Reusable `.kl` without copying sources — search paths for
`import name`. `module` / `pub` semantics: [12-modules.md](12-modules.md)
([006](../issues/006-modules.md)). No package manager.

## `import name` resolution

In each search slot (first hit wins; **file and directory at once** =
error):

1. sibling: `name.kl` **or** directory `name/`
2. `lib/name.kl` **or** `lib/name/`
3. `-I <dir>/…`
4. `$KLIN_PATH` (`:` / `;`)
5. `$KLIN_STDLIB` / repo `stdlib/`

### File vs directory (047)

| | Meaning |
|---|---|
| `name.kl` | one file = one module (as before) |
| `name/*.kl` | **one** module; all files with `module name`; `*_test.kl` skipped |

In a directory package: without `pub` = private within the module (files see each
other); `pub` = export on `import`. Entry (`klin run app.kl`) also loads
siblings with the same `module`.

`$KLIN_STDLIB` remains stdlib override; do not combine with `$KLIN_PATH`.

## Aliases and path import (048)

```klin
import geom                      // qualifier = geom
import geom oso                  // local alias: qualifier = oso (geom unavailable)
import "sub/osa"                 // string; qualifier = last segment (osa)
import "sub/osa" aa              // string + alias: qualifier = aa
```

- Alias/qualifier is a **frontend** concept — C mangling uses the real
  `module` name (e.g. `oso.f()` → `geom_f`).
- Alias replaces default qualifier (after `import geom oso` there is no `geom.…`).
- String is a **relative path** (may contain `/`), resolved as above
  (`lib/`, `-I`, `$KLIN_PATH`, file or directory). Default qualifier = last
  segment without `.kl`. Directory package: files must declare `module <segment>`.
- Same qualifier bound to two different specifiers = error. C keyword
  as alias = error.

## Examples

Single-file in `lib/` ([020](../issues/020-klin-libraries.md)):

```sh
dart run bin/klin.dart run examples/klin_lib/app.kl
```

Directory package ([047](../issues/047-directory-modules.md)):

```sh
dart run bin/klin.dart run examples/pkg_geom/app.kl
# → 25
```

```text
examples/pkg_geom/
  app.kl
  geom/
    vec.kl        # module geom — pub struct Vec2
    len.kl        # module geom — private sq + pub len_sq
    len_test.kl   # skipped on run
```

Emission is still **one** `.c`. Modules: [12-modules.md](12-modules.md).

## Remote (`github` / `gitlab`) — issue 049

```klin
import "github/klin-lang/osa"
```

- First segment `github` or `gitlab` → package from cache (`$KLIN_CACHE` / `~/.klin/pkg/…`).
- Missing from cache → error; first `klin get github/klin-lang/osa@v0.1.0`
  (writes `klin.mod` + `klin.lock`).
- Install copies `.kl` plus freestanding `@[link]` units (`.c` / `.h` / `.s` / `.S`);
  `*_test.kl` stays out of the cache tree.
- `klin run` without network. Manifest: `klin.mod` (`require path ref`).
- Lock: `klin.lock` — commit SHA + `sha256` of sources ([065](../issues/065-project-lockfile.md) ✅).
- Fixture: https://github.com/klin-lang/osa ([063](../issues/063-remote-fixture-osa.md)).

`outdated` / `upgrade` → [066](../issues/066-klin-upgrade-outdated.md) ✅.

## Device SVD (`$device`) — issue 053

```klin
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC,GPIOA")
```

- This is **not** `import` — vendor artifact (SVD), not a Klin module.
- `klin get …/file.svd@ref` → `$KLIN_CACHE/asset/host/owner/repo/…`,
  `klin.mod` line `device path ref`, `klin.lock` (commit + sha256 of file).
- MVP allowlist: `github/tinygo-org/stm32-svd`. Local path still works.
- Example: [`examples/stm32/device_f411/`](../examples/stm32/device_f411/).
- Board / CubeMX `.ioc` — outside MVP (separate issue after 053).

## Out of scope

Separate `.a` from Klin libs. Aliases / path import: [048](../issues/048-import-aliases.md) ✅.
C FFI: [09-ffi-c.md](09-ffi-c.md). CLI: [06-cli.md](06-cli.md).
