# Source formatting (`klin fmt`)

Issue: [033](../issues/033-gofmt-style.md).

## Principle

Like `gofmt`: **one style, zero flags**. Indentation debates end with
`klin fmt -w`.

## Rules (MVP)

- indentation: **4 spaces**
- K&R / Go braces: `fn main() {` on the same line; `} else {` on one line
- spaces around binary operators and after commas
- blank line between top-level declarations (`struct` / `fn`)
- `module` / `import` at the top, then blank line, then declarations

## Usage

```sh
dart run bin/klin.dart fmt examples/hello.kl          # stdout
dart run bin/klin.dart fmt -w path/a.kl path/b.kl     # write in place
```

Input: lex → parse (`ModuleUnit`) → pretty-print. No preprocess / check / emit.
`//` comments are collected beside the token stream and replayed: a
full-line comment stays with the next declaration / field / statement;
a same-line `//` stays as a trailer on that line. File-header and
file-footer comments are kept.

## Limitations

- No `/* */` block comments (language: `//` only).
- Files with `$fn` / `$peripherals_from_svd` macros are not valid Klin
  before expand — format `--emit-pp` output or a file without `$`.
