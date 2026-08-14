# Modules (issue 006)

`module` / `import` / `pub` — encapsulation instead of flat C linkage.
Tutorial: [guide.md](guide.md) §8. Search paths (`lib/`, `-I`, directory
package): [11-klin-libraries.md](11-klin-libraries.md).

## Syntax

```klin
module geom

pub struct Vec2 {
    x: i32
    y: i32
}

pub fn (v: Vec2) len_sq(): i32 {
    return v.x * v.x + v.y * v.y
}
```

```klin
module app
import geom

fn main() {
    let p = geom.Vec2{ x: 3, y: 4 }
    printf("%d\n", p.len_sq())
}
```

- `module name` — module declaration for the file (or all files in a directory package)
- `import name` — qualifier in use: `name.Symbol`
- without `pub` = private in **module**; `pub` = visible after `import`

## C emission

- mangling: `module_Type_method` (e.g. `geom_Vec2_len_sq`) — [01-decisions.md](01-decisions.md)
- private symbols → `static` in generated `.c`
- whole program still **one** `.c`

## File vs directory

| Form | Meaning |
|---|---|
| `name.kl` | one file = one module |
| `name/*.kl` | **one** module (issue [047](../issues/047-directory-modules.md)); `*_test.kl` skipped |

Entry (`klin run app.kl`) also loads siblings with the same `module`.
Resolution details: [11-klin-libraries.md](11-klin-libraries.md).

## Examples

Multiple modules (separate files):

```sh
dart run bin/klin.dart run examples/modules/app.kl
```

Directory = one package:

```sh
dart run bin/klin.dart run examples/pkg_geom/app.kl
# → 25
```

## Out of scope

Aliases / `import "…"`: [048](../issues/048-import-aliases.md).
Remote GitHub: [049](../issues/049-remote-imports.md).
CLI: [06-cli.md](06-cli.md).
