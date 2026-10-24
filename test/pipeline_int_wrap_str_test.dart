@Tags(['unit'])
library;

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/project.dart';
import 'package:test/test.dart';

void main() {
  test('narrow arithmetic and defined shifts are in the C', () {
    final program = loadProject('test/int_wrap.kl');
    Checker().check(program);
    final c = emitC(program, 'test/int_wrap.kl');
    expect(c, contains('(uint8_t)(a + b)'));
    expect(c, contains('(uint8_t)(~(a))'));
    expect(c, contains('(int8_t)(a + b)'));
    expect(c, contains('(uint16_t)(a + b)'));
    expect(c, contains('(int16_t)(a + b)'));
    expect(c, contains('klin_shl_u8(a, (uint64_t)(n))'));
    expect(c, contains('klin_shr_i8(a, (uint64_t)(n))'));
    expect(c, contains('klin_shl_i32(a, (uint64_t)(n))'));
    expect(c, contains('klin_shr_i64(a, (uint64_t)(n))'));
    expect(c, contains('static inline uint8_t klin_shl_u8(uint8_t v, uint64_t n)'));
    expect(c, contains('static inline int32_t klin_shr_i32(int32_t v, uint64_t n)'));
    expect(c, contains('if (n >= 32u) return v < 0 ? (int32_t)-1 : (int32_t)0;'));
    expect(c, contains('f = klin_shl_u32(f, (uint64_t)(n));'));
    expect(c, contains('uint8_t * klin_val_0 = &xs[int_wrap_idx()];'));
    expect(c, contains('*klin_val_0 = klin_shl_u8(*klin_val_0, (uint64_t)(1));'));
    expect(c, isNot(contains('xs[idx()] <<=')));
  });

  test('constant overflow and an out-of-range shift stay errors', () {
    expectCheck('fn main() { let x: u8 = 200 + 100 }', 'out of range');
    expectCheck(
      'const X: u8 = 1 << 8\nfn main() {}',
      'shift by `8` is wider than `u8`',
    );
    expectCheck(
      'fn main() { let x: i32 = 1 << 40 }',
      'shift by `40` is wider than `i32`',
    );
    expectCheck(
      'const X: i32 = 1 << -1\nfn main() {}',
      'shift by a negative count',
    );
  });

  test('a zero str is an empty string in locals, fields, and globals', () {
    final program = loadProject('test/str_zero.kl');
    Checker().check(program);
    final c = emitC(program, 'test/str_zero.kl');
    expect(c, contains('const char* s = "";'));
    expect(c, contains('str_zero_Row row = { .name = "", .n = 0 };'));
    expect(c, contains('str_zero_Wrap w = { .row = { .name = "", .n = 0 } };'));
    expect(c, contains('str_zero_Bag b = { .ss = { "", "" } };'));
    expect(c, contains('static const char* str_zero_frozen = "";'));
    expect(c, contains('static const char* str_zero_g = "";'));
    expect(
      c,
      contains('static str_zero_Row str_zero_grow = { .name = "", .n = 0 };'),
    );
    expect(c, contains('klin_res_str r = { .is_err = false, .u.ok = "" };'));
    expect(c, contains('str_zero_Hook h = { .name = "", .cb = 0 };'));
    expect(c, isNot(contains('= NULL')));
  });

  test('a struct literal must still name every str field', () {
    expectCheck('''
struct Row {
    name: str
    n: i32
}
fn main() {
    let row = Row { n: 1 }
}
''', 'literal `Row` requires all fields');
  });

  test('an async str local is stored as an empty string', () {
    const source = '''
struct Row { name: str }
async fn work() {
    let s: str
    let row: Row
    let ss: [2]str
    printf("%d %d %d\\n", s.len, row.name.len, ss[0].len)
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'async_str.kl');
    expect(c, contains('st->s = "";'));
    expect(c, contains('st->row = (Row){ .name = "" };'));
    expect(c, contains('st->ss[0] = "";'));
    expect(c, contains('st->ss[1] = "";'));
  });
}

void expectCheck(String source, String fragment) {
  expect(
    () {
      final program = Parser(Lexer(source).tokenize()).parse();
      Checker().check(program);
    },
    throwsA(
      predicate(
        (e) => e is CheckError && e.toString().contains(fragment),
        'CheckError containing $fragment',
      ),
    ),
  );
}
