@Tags(['e2e'])
library;

import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/project.dart';
import 'package:klin/remote.dart';
import 'package:test/test.dart';

import 'support/klin_cli.dart';

import 'support/compile_and_run.dart';

void main() {

  setUpAll(() async {
    await ensureKlinE2eBin();
  });

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });
  test('golden: defer — LIFO order', () async {
    final result = await compileAndRun('test/defer_order.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_order.out').readAsString());
  });

  test('golden: defer before break is block-scoped', () async {
    final result = await compileAndRun('test/defer_break.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_break.out').readAsString());
  });

  test('golden: defer before continue is block-scoped', () async {
    final result = await compileAndRun('test/defer_continue.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_continue.out').readAsString());
  });

  test('golden: defer before return preserves value', () async {
    final result = await compileAndRun('test/defer_return.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_return.out').readAsString());
  });

  test('early return does not run a later defer', () async {
    const source = '''
fn main() {
  defer puts("a")
  puts("body")
  return
  defer puts("b")
}
''';
    final dir = await Directory.systemTemp.createTemp('klin_defer_early_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final kl = File('${dir.path}/early.kl');
    await kl.writeAsString(source);
    final result = await compileAndRun(kl.path, dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'body\na\n');
  });

  test('golden: function called before definition', () async {
    final result = await compileAndRun('test/call_before_def.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/call_before_def.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: recursive fib', () async {
    final result = await compileAndRun('test/fib.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/fib.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: Vec2 — structs, fields, and methods', () async {
    final result = await compileAndRun('test/vec2.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/vec2.out').readAsString());

    final program = loadProject('test/vec2.kl');
    Checker().check(program);
    final c = emitC(program, 'test/vec2.kl');
    expect(c, contains('vec2_Vec2_translate(vec2_Vec2 *v'));
    expect(c, isNot(contains('mut')));
  });

  test('golden: project with modules', () async {
    final result = await compileAndRun('test/modules/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/modules/app.out').readAsString());

    final program = loadProject('test/modules/app.kl');
    Checker().check(program);
    final c = emitC(program, 'test/modules/app.kl');
    expect(c, contains('typedef struct {'));
    expect(c, contains('} geom_Vec2;'));
    expect(c, contains('static void geom_helper(void);'));
    expect(c, contains('geom_Vec2_len_sq(geom_Vec2 v)'));
    expect(c, contains('util_add(2, 3)'));
  });

  test('explicit import alias `import geom oso` (issue 048)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_alias048_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/geom.kl').writeAsStringSync('''
module geom
pub fn answer(): i32 { return 42 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom oso
fn main() {
  printf("%d\\n", oso.answer())
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '42\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    // The alias is frontend-only; C uses the real module name.
    expect(c, contains('geom_answer'));
  });

  test('string path import `import "sub/osa"` with optional alias (issue 048)',
      () async {
    final dir = Directory.systemTemp.createTempSync('klin_pathimp048_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/sub').createSync();
    File('${dir.path}/sub/osa.kl').writeAsStringSync('''
module osa
pub fn answer(): i32 { return 7 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import "sub/osa"
import "sub/osa" aa
fn main() {
  printf("%d %d\\n", osa.answer(), aa.answer())
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '7 7\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('osa_answer'));
  });

  test('string path import tolerates a trailing `.kl` (issue 048)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_pathkl048_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/sub').createSync();
    File('${dir.path}/sub/osa.kl').writeAsStringSync('''
module osa
pub fn answer(): i32 { return 9 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import "sub/osa.kl"
fn main() {
  printf("%d\\n", osa.answer())
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '9\n');
  });

  test(
    'klin get device SVD + \$device offline preprocess (issue 053 network)',
    () async {
    final cache = Directory.systemTemp.createTempSync('klin_get053_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_getwork053_');
    addTearDown(() => work.deleteSync(recursive: true));
    const devicePath =
        'github/tinygo-org/stm32-svd/svd/stm32f411.svd';
    File('${work.path}/app.kl').writeAsStringSync('''
\$device("$devicePath", "RCC,GPIOA")
fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
}
''');
    final repoRoot = Directory.current.path;
    final env = {
      ...Platform.environment,
      'KLIN_CACHE': cache.path,
    };

    final get = await runKlin(['get', '$devicePath@main'], workingDirectory: work.path,
      environment: env,);
    expect(get.exitCode, 0, reason: '${get.stderr}${get.stdout}');
    expect(File('${work.path}/klin.mod').existsSync(), isTrue);
    final mod = loadKlinMod(File('${work.path}/klin.mod'));
    expect(mod.devices[devicePath], 'main');
    expect(File('${work.path}/klin.lock').existsSync(), isTrue);
    final lock = loadKlinLock(File('${work.path}/klin.lock'));
    final entry = lock.packages[devicePath]!;
    expect(entry.version, 'main');
    expect(entry.commit, matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(entry.hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    final svdCached =
        '${cache.path}/asset/github/tinygo-org/stm32-svd/svd/stm32f411.svd';
    expect(File(svdCached).existsSync(), isTrue);
    expect(fileContentHash(svdCached), entry.hash);

    final pp = await runKlin(['--emit-pp', '${work.path}/app.kl'], workingDirectory: work.path,
      environment: env,);
    expect(pp.exitCode, 0, reason: '${pp.stderr}${pp.stdout}');
    final ppFile = File('${work.path}/out/app.pp.kl');
    // emit-pp may write under cwd out/ — accept either
    final ppText = ppFile.existsSync()
        ? ppFile.readAsStringSync()
        : File('$repoRoot/out/app.pp.kl').readAsStringSync();
    expect(ppText, contains('RCC_AHB1ENR_GPIOAEN_set(1)'));
  },
    timeout: Timeout(Duration(minutes: 3)),
    tags: ['e2e_net'],
  );

  test('import resolves from lib/ next to the importer (issue 020)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_lib_dir_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/lib').createSync();
    File('${dir.path}/lib/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return a + b }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import mathx
fn main() {
  printf("%d\\n", mathx.add(2, 3))
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '5\n');
  });

  test('import -I / KLIN_PATH; sibling wins over lib/ (issue 020)', () async {
    final root = Directory.systemTemp.createTempSync('klin_lib_path_');
    addTearDown(() => root.deleteSync(recursive: true));
    final vendor = Directory('${root.path}/vendor')..createSync();
    File('${vendor.path}/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return a + b }
''');
    final appDir = Directory('${root.path}/app')..createSync();
    Directory('${appDir.path}/lib').createSync();
    File('${appDir.path}/lib/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return 99 }
''');
    File('${appDir.path}/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return 7 }
''');
    File('${appDir.path}/app.kl').writeAsStringSync('''
module app
import mathx
fn main() {
  printf("%d\\n", mathx.add(2, 3))
}
''');

    // Sibling wins over lib/.
    final sibling = await compileAndRun('${appDir.path}/app.kl', tmp);
    expect(sibling.exitCode, 0, reason: sibling.stderr);
    expect(sibling.stdout, '7\n');

    File('${appDir.path}/mathx.kl').deleteSync();
    Directory('${appDir.path}/lib').deleteSync(recursive: true);

    // -I finds vendor.
    final viaI = await runKlin(['run',
        '-I',
        vendor.path,
        '${appDir.path}/app.kl']);
    expect(viaI.exitCode, 0, reason: '${viaI.stderr}${viaI.stdout}');
    expect(viaI.stdout, '5\n');

    // $KLIN_PATH finds vendor.
    final viaEnv = await runKlin(['run', '${appDir.path}/app.kl'], environment: {
        ...Platform.environment,
        'KLIN_PATH': vendor.path,
      },);
    expect(viaEnv.exitCode, 0, reason: '${viaEnv.stderr}${viaEnv.stdout}');
    expect(viaEnv.stdout, '5\n');
  });

  test('directory package is one module; private shared across files (issue 047)',
      () async {
    final result = await compileAndRun('examples/pkg_geom/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '25\n');

    final program = loadProject('examples/pkg_geom/app.kl');
    Checker().check(program);
    final c = emitC(program, 'examples/pkg_geom/app.kl');
    expect(c, contains('static int32_t geom_sq('));
    expect(c, contains('geom_Vec2_len_sq('));
  });

  test('entry loads same-module sibling files (issue 047)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_entry_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/helper.kl').writeAsStringSync('''
module app
fn answer(): i32 { return 7 }
''');
    File('${dir.path}/main.kl').writeAsStringSync('''
module app
fn main() {
  printf("%d\\n", answer())
}
''');
    final result = await compileAndRun('${dir.path}/main.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '7\n');
  });

  test('golden: nested mutable places (issue 069 checker unblock)', () async {
    final result = await compileAndRun('test/nested_mut_place.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/nested_mut_place.out').readAsString());

    final source = File('test/nested_mut_place.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/nested_mut_place.kl');
    // A mut receiver's nested array element writes through the pointer.
    expect(c, contains('b->slots[i] = v;'));
    // Nested struct field and array-element field through a mut variable.
    expect(c, contains('o.inner.x = 5;'));
    expect(c, contains('xs[0].x = 9;'));
  });

  test('golden: assign to a field through a *mut deref (parser + checker)',
      () async {
    final result = await compileAndRun('test/deref_field_assign.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/deref_field_assign.out').readAsString());

    final source = File('test/deref_field_assign.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/deref_field_assign.kl');
    expect(c, contains('(*(p)).x = 7;'));
    expect(c, contains('(*(p)).y = 9;'));
  });

  test('golden: associated functions on types (Type.func)', () async {
    final result = await compileAndRun('test/assoc_fn.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/assoc_fn.out').readAsString());

    final program = loadProject('test/assoc_fn.kl');
    Checker().check(program);
    final c = emitC(program, 'test/assoc_fn.kl');
    // Associated functions emit as plain C functions with no receiver arg,
    // mangled `Type_func`.
    expect(c, contains('Color_from_name(const char* s)'));
    expect(c, contains('Point_new(int32_t x, int32_t y)'));
    expect(c, contains('Point_new(3, 4)'));
    expect(c, contains('str_eq('));
  });

  test('imported associated function via mod.Type.func (Type.func)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_impassoc079_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/geom.kl').writeAsStringSync('''
module geom
pub struct Point { x, y: i32 }
pub fn Point.origin(): Point { return Point{ x: 0, y: 0 } }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  let p: geom.Point = geom.Point.origin()
  printf("%d\\n", p.x)
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '0\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('geom_Point_origin'));
  });

  test('golden: number + character literals (issue 081)', () async {
    final result = await compileAndRun('test/number_literals.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/number_literals.out').readAsString());

    final source = File('test/number_literals.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/number_literals.kl');
    // Binary and octal literals emit as portable 0x (no `0b`/`0o`).
    expect(c, contains('uint32_t mask = 0xf0;'));
    expect(c, contains('uint32_t bit = 0x5;'));
    expect(c, contains('uint32_t perm = 0x1ed;')); // 0o755 == 493
    expect(c, isNot(contains('0b')));
    expect(c, isNot(contains('0o')));
    // Float exponents pass through; `0b100` array length becomes 4.
    expect(c, contains('double small = 1.5e-3;'));
    expect(c, contains('int32_t xs[4]'));
    expect(c, contains("uint8_t a = 'A';"));
    expect(c, contains("uint8_t nl = '\\n';"));
  });

  test('golden: slice, array, and mutable pointer', () async {
    final result = await compileAndRun('test/slice_sum.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/slice_sum.out').readAsString());

    final source = File('test/slice_sum.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/slice_sum.kl');
    expect(c, contains('klin_slice_i32'));
    expect(c, contains('int32_t buf[4] = { 10, 20, 30, 40 };'));
    expect(c, contains('(klin_slice_i32){ buf, 4 }'));
    expect(c, contains('xs.ptr[i]'));
    expect(c, contains('volatile uint32_t * p'));
    expect(c, contains('(volatile uint32_t *)(uintptr_t)'));
  });

  test('--emit-c writes C without compiling or running', () async {
    final source = File('${tmp.path}/emit_only.kl');
    await source.writeAsString('''
@[link("driver.a")]
fn main() {}
''');
    final proc = await runKlin(['--emit-c', source.path]);
    final cFile = File('out/emit_only.c');
    final linkFile = File('out/emit_only.link');
    addTearDown(() async {
      if (await cFile.exists()) await cFile.delete();
      if (await linkFile.exists()) await linkFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await cFile.exists(), isTrue);
    expect(await linkFile.readAsString(), 'driver.a\n');
  });

  test('--emit-c .link resolves existing @[link] paths to absolute', () async {
    final driver = File('${tmp.path}/usb_stub.c');
    await driver.writeAsString('void klin_usb_stub(void) {}\n');
    final source = File('${tmp.path}/emit_abs_link.kl');
    await source.writeAsString('''
@[link("usb_stub.c")]
fn main() {}
''');
    final proc = await runKlin(['--emit-c', source.path]);
    final cFile = File('out/emit_abs_link.c');
    final linkFile = File('out/emit_abs_link.link');
    addTearDown(() async {
      if (await cFile.exists()) await cFile.delete();
      if (await linkFile.exists()) await linkFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    final linkBody = await linkFile.readAsString();
    expect(linkBody.trim(), driver.absolute.path);
  });

  test('--emit-h writes header without compiling or running', () async {
    final source = File('${tmp.path}/emit_h_only.kl');
    await source.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 { return a + b }
fn main() {}
''');
    final proc = await runKlin(['--emit-h', source.path]);
    final hFile = File('out/emit_h_only.h');
    final cFile = File('out/emit_h_only.c');
    addTearDown(() async {
      if (await hFile.exists()) await hFile.delete();
      if (await cFile.exists()) await cFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await hFile.exists(), isTrue);
    expect(await cFile.exists(), isFalse);
    expect(await hFile.readAsString(), contains('int32_t klin_add'));
  });

  test('--emit-c --emit-h writes both artifacts', () async {
    final source = File('${tmp.path}/emit_both.kl');
    await source.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 { return a + b }
fn main() {}
''');
    final proc = await runKlin(['--emit-c', '--emit-h', source.path]);
    final hFile = File('out/emit_both.h');
    final cFile = File('out/emit_both.c');
    addTearDown(() async {
      if (await hFile.exists()) await hFile.delete();
      if (await cFile.exists()) await cFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await hFile.exists(), isTrue);
    expect(await cFile.exists(), isTrue);
  });

}
