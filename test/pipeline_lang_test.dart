@Tags(['unit'])
library;

import 'dart:io';

import 'package:klin/ast.dart';
import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/fmt.dart';
import 'package:klin/lexer.dart';
import 'package:klin/link_args.dart';
import 'package:klin/parser.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/project.dart';
import 'package:klin/remote.dart';
import 'package:klin/token.dart';
import 'package:test/test.dart';


void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('different !*T types emit separate result typedefs', () {
    const source = '''
fn a(): !*i32 { return error(1) }
fn b(): !*f64 { return error(2) }
fn main() {
  let x = a() or { cast(*i32, 0) }
  let y = b() or { cast(*f64, 0) }
  printf("%p %p\\n", x, y)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'ptr_results.kl');
    expect(c, contains('} klin_res_ptr_i32;'));
    expect(c, contains('} klin_res_ptr_f64;'));
    expect(c, isNot(contains('} klin_res_ptr;')));
  });

  test('golden: emitted C is readable and contains #line', () {
    final source = File('test/hello.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/hello.kl');

    expect(c, contains('#include <stdio.h>'));
    expect(c, contains('int main(void) {'));
    expect(c, contains('puts("hello");'));
    expect(c, contains('puts("from Klin");'));
    expect(c, contains('return 0;'));
    expect(c, contains('#line '));
    expect(c, contains('test/hello.kl'));
  });

  test('lexer: logical tokens && || (issue 097)', () {
    final tokens = Lexer('a&&b||c&d|e').tokenize();
    expect(
      tokens.map((t) => t.kind).toList(),
      [
        TokenKind.ident,
        TokenKind.ampAmp,
        TokenKind.ident,
        TokenKind.pipePipe,
        TokenKind.ident,
        TokenKind.ampersand,
        TokenKind.ident,
        TokenKind.pipe,
        TokenKind.ident,
        TokenKind.eof,
      ],
    );
  });

  test('klin fmt: logical operators (issue 097)', () {
    const ugly = 'fn main(){let x=true&&false||!true}';
    final once = formatSource(ugly);
    expect(once, contains('true && false || !true'));
    expect(formatSource(once), once);
  });

  test('lexer: bitwise tokens << >> | ^ ~ and compounds (issue 078)', () {
    final tokens = Lexer('a<<b>>c|d^e~f&g a&=b|=c^=d<<=e>>=f').tokenize();
    expect(
      tokens.map((t) => t.kind).toList(),
      [
        TokenKind.ident,
        TokenKind.lessLess,
        TokenKind.ident,
        TokenKind.greaterGreater,
        TokenKind.ident,
        TokenKind.pipe,
        TokenKind.ident,
        TokenKind.caret,
        TokenKind.ident,
        TokenKind.tilde,
        TokenKind.ident,
        TokenKind.ampersand,
        TokenKind.ident,
        TokenKind.ident,
        TokenKind.ampEqual,
        TokenKind.ident,
        TokenKind.pipeEqual,
        TokenKind.ident,
        TokenKind.caretEqual,
        TokenKind.ident,
        TokenKind.lessLessEqual,
        TokenKind.ident,
        TokenKind.greaterGreaterEqual,
        TokenKind.ident,
        TokenKind.eof,
      ],
    );
  });

  test('klin fmt: bitwise operators (issue 078)', () {
    const ugly = 'fn main(){let x=1<<2|3&4^~5\nlet mut y=0\ny|=1\ny<<=2}';
    final once = formatSource(ugly);
    expect(once, contains('1 << 2 | 3 & 4 ^ ~5'));
    expect(once, contains('y |= 1'));
    expect(once, contains('y <<= 2'));
    expect(formatSource(once), once);
  });

  test('lexer: arithmetic compound assign tokens', () {
    final tokens = Lexer('a+=b-=c*=d/=e%=f').tokenize();
    expect(
      tokens.map((t) => t.kind).toList(),
      [
        TokenKind.ident,
        TokenKind.plusEqual,
        TokenKind.ident,
        TokenKind.minusEqual,
        TokenKind.ident,
        TokenKind.starEqual,
        TokenKind.ident,
        TokenKind.slashEqual,
        TokenKind.ident,
        TokenKind.percentEqual,
        TokenKind.ident,
        TokenKind.eof,
      ],
    );
  });

  test('klin fmt: preserves := short decl (issue 055)', () {
    final ugly = File('test/fmt_short_decl.kl').readAsStringSync();
    final expected = File('test/fmt_short_decl.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);
  });

  test('klin fmt: preserves = in for-init assign (issue 151)', () {
    final ugly = File('test/fmt_for_c_init_assign.kl').readAsStringSync();
    final expected =
        File('test/fmt_for_c_init_assign.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);
  });

  test('match statement calling only puts still includes <stdio.h>', () {
    const source = '''
fn main() {
  match 1 {
    1 { puts("one") }
    else { puts("other") }
  }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'match_stdio.kl');
    expect(c, contains('#include <stdio.h>'));
  });

  test('klin fmt: formats match arms (issue 014)', () {
    final ugly = File('test/fmt_match.kl').readAsStringSync();
    final expected = File('test/fmt_match.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);
  });

  test('klin fmt: formats enum declarations (issue 072)', () {
    const ugly =
        'enum Color{Red,Green,Blue}\nenum Status : u8 { Ok , Warn = 5 , Err }\nfn main(){}';
    final once = formatSource(ugly);
    expect(once, contains('enum Color {\n    Red\n    Green\n    Blue\n}'));
    expect(once, contains('enum Status: u8 {\n    Ok\n    Warn = 5\n    Err\n}'));
    expect(formatSource(once), once);
  });

  test('enum match with else stays non-exhaustive-ok (issue 129)', () {
    const source = '''
enum Color { Red, Green, Blue }
fn main() {
    let c: Color = Color.Red
    match c {
        Color.Red { }
        else { }
    }
    let n = match c {
        Color.Green { 1 }
        else { 0 }
    }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
  });

  test('klin fmt: formats pick expression (issue 085)', () {
    final ugly = File('test/fmt_pick.kl').readAsStringSync();
    final expected = File('test/fmt_pick.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);
  });

  test('nested fn types emit typedefs leaves-first', () {
    final file = File('${Directory.systemTemp.path}/klin_nested_fn.kl');
    file.writeAsStringSync(r'''
fn id(x: i32): i32 {
    return x
}

fn choose(): fn(i32): i32 {
    return id
}

fn main() {
    let f = choose()
    printf("%d\n", f(7))
}
''');
    final program = loadProject(file.path);
    Checker().check(program);
    final c = emitC(program, file.path);
    // Inner fn(i32):i32 typedef must appear before any that mention it as return.
    final innerName = 'klin_fn_i32__i32';
    final outerRet = c.indexOf('(*klin_fn_void_');
    expect(c.indexOf(innerName), lessThan(outerRet == -1 ? c.length : outerRet));
    expect(c, contains(innerName));
  });

  test('fmt preserves interpolation syntax', () {
    final source = r'''
fn main() {
puts("hi $name ${n:%d} ${x:0.00} ${t:s8}")
}
''';
    final formatted = formatSource(source);
    expect(formatted, contains(r'$name'));
    expect(formatted, contains(r'${n:%d}'));
    expect(formatted, contains(r'${x:0.00}'));
    expect(formatted, contains(r'${t:s8}'));
  });

  test(r'$fn block param + integer args (rtos_task shape)', () {
    final expanded = preprocess(r'''
$fn rtos_task(name: name, stack: name, prio: name, body: block) {
@[codename("task_$name")]
fn task_$name(arg: *mut void) {
$body
}
fn start_$name() {
  let n: i32 = $stack
  let p: i32 = $prio
}
}
$rtos_task(blink, 512, 2) {
  let x: i32 = 1
}
fn main() {}
''', path: 'mod/rtos_shape.kl');
    expect(expanded, contains('@[codename("task_blink")]'));
    expect(expanded, contains('fn task_blink(arg: *mut void)'));
    expect(expanded, contains('let x: i32 = 1'));
    expect(expanded, contains('fn start_blink()'));
    expect(expanded, contains('let n: i32 = 512'));
    expect(expanded, contains('let p: i32 = 2'));
    expect(expanded, isNot(contains(r'$rtos_task')));
  });

  test(r'macros from path import + $mod qualifier (059 A1 lite)', () {
    final dir = Directory.systemTemp.createTempSync('klin_macro_import_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pkg = Directory('${dir.path}/mylib')..createSync();
    File('${pkg.path}/macros.kl').writeAsStringSync(r'''
module mylib
$fn greet(name: name, body: block) {
fn hello_$name() {
  $mod.ping()
$body
}
}
pub fn ping() {}
''');
    File('${dir.path}/app.kl').writeAsStringSync(r'''
import "mylib" lib
$greet(world) {
  let z: i32 = 0
}
fn main() {
  hello_world()
}
''');
    final expanded = preprocess(
      File('${dir.path}/app.kl').readAsStringSync(),
      path: '${dir.path}/app.kl',
    );
    expect(expanded, contains('fn hello_world()'));
    expect(expanded, contains('lib.ping()'));
    expect(expanded, contains('let z: i32 = 0'));
    expect(expanded, isNot(contains(r'$mod')));
  });

  test(r'nested macros: block body may invoke another $fn (rtos+event_loop)',
      () {
    final expanded = preprocess(r'''
$fn event_loop(ex: name, body: block) {
let mut $ex: Executor
$body
run(&$ex)
}
$fn rtos_task(name: name, body: block) {
fn task_$name() {
$body
}
}
$rtos_task(net) {
  $event_loop(ex) {
    every_ms(&ex)
  }
}
fn main() {}
''', path: 'mod/nested_macros.kl');
    expect(expanded, contains('fn task_net()'));
    expect(expanded, contains('let mut ex: Executor'));
    expect(expanded, contains('every_ms(&ex)'));
    expect(expanded, contains('run(&ex)'));
    expect(expanded, isNot(contains(r'$rtos_task')));
    expect(expanded, isNot(contains(r'$event_loop')));
  });

  test(r'$ in macro strings/comments is not an unsubstituted slot', () {
    final expanded = preprocess(r'''
$fn note(T: type) {
fn f(): $T {
  // keep $hint
  puts("$USD")
  return 0
}
}
$note(i32)
''', path: 't.kl');
    expect(expanded, contains(r'// keep $hint'));
    expect(expanded, contains(r'puts("$USD")'));
    expect(expanded, contains('fn f(): i32'));
  });

  test(r'$peripherals_from_svd rewrites fluent MMIO (issue 027)', () {
    final dir = Directory('${tmp.path}/svd_fluent')..createSync();
    File('${dir.path}/tiny.svd').writeAsStringSync('''
<device><peripherals>
  <peripheral><name>RCC</name><baseAddress>0x40023800</baseAddress><registers>
    <register><name>AHB1ENR</name><addressOffset>0x30</addressOffset><fields>
      <field><name>GPIOAEN</name><bitOffset>0</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
  <peripheral><name>GPIOA</name><baseAddress>0x40020000</baseAddress><registers>
    <register><name>MODER</name><addressOffset>0</addressOffset><fields>
      <field><name>MODER5</name><bitOffset>10</bitOffset><bitWidth>2</bitWidth>
        <enumeratedValues><enumeratedValue><name>Output</name><value>1</value></enumeratedValue></enumeratedValues>
      </field>
    </fields></register>
    <register><name>ODR</name><addressOffset>0x14</addressOffset><fields>
      <field><name>ODR5</name><bitOffset>5</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
</peripherals></device>
''');
    final klPath = '${dir.path}/blinky.kl';
    File(klPath).writeAsStringSync(r'''
$peripherals_from_svd("tiny.svd", "RCC,GPIOA")
fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
  GPIOA.MODER.MODER5.write(.Output)
  GPIOA.ODR.ODR5.toggle()
}
''');
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
    );
    expect(expanded, contains('@[cinclude("tiny_regs.h")]'));
    expect(
      expanded,
      contains('@[cimport, cheader, codename("GPIOA_ODR_ODR5_toggle")]'),
    );
    expect(expanded, contains('RCC_AHB1ENR_GPIOAEN_set(1)'));
    expect(expanded, contains('GPIOA_MODER_MODER5_write(1)'));
    expect(expanded, contains('GPIOA_ODR_ODR5_toggle()'));
    expect(expanded, isNot(contains('RCC.AHB1ENR')));
    expect(File('${dir.path}/tiny_regs.h').existsSync(), isTrue);

    expect(
      () => preprocess(
        r'''
$peripherals_from_svd("tiny.svd", "RCC,GPIOA")
fn main() { GPIOA.ODR.ODR5.toggle(1) }
''',
        path: klPath,
      ),
      throwsA(
        predicate(
          (e) =>
              e is PreprocessError && e.toString().contains('takes no arguments'),
        ),
      ),
    );
  });

  test('syntax error: message includes line number', () async {
    final source = await File('test/bad_syntax.kl').readAsString();
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) {
          final msg = e.toString();
          // `42` is on line 3, where the lexer reports the position.
          return msg.contains('3:') && (e is LexError || e is ParseError);
        }),
      ),
    );
  });

  test('type error: mismatch includes position', () {
    final source = File('test/type_mismatch.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('type mismatch') &&
              msg.contains('i32') &&
              msg.contains('bool');
        }),
      ),
    );
  });

  test('import alias maps to the file module declaration', () {
    final dir = Directory.systemTemp.createTempSync('klin_mod_alias_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/file_a.kl').writeAsStringSync('''
module real
pub fn answer(): i32 { return 42 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import file_a
fn main() {
  printf("%d\\n", file_a.answer())
}
''');
    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('real_answer'));
    expect(c, isNot(contains('file_a_answer')));
  });

  test('remote import missing cache suggests klin get (issue 049)', () {
    final cache = Directory.systemTemp.createTempSync('klin_nocache049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    expect(
      () => loadProject(
        'test/remote_osa.kl',
        klinCacheDir: cache.path,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          contains('klin get'),
        ),
      ),
    );
  });

  test('remote import incomplete @[link] units suggests klin get', () {
    final cache = Directory.systemTemp.createTempSync('klin_incomplete_link_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_incomplete_work_');
    addTearDown(() => work.deleteSync(recursive: true));
    final pkg = Directory('${cache.path}/pkg/github/klin-lang/linkpkg')
      ..createSync(recursive: true);
    File('${pkg.path}/usb.kl').writeAsStringSync('''
module usb
@[link("usb_cdc_rp.c")]
pub fn out() {}
''');
    File('${pkg.path}/.pin').writeAsStringSync('v0.1.0\n');
    File('${work.path}/app.kl').writeAsStringSync('''
import "github/klin-lang/linkpkg"
fn main() { usb.out() }
''');
    expect(
      () => loadProject(
        '${work.path}/app.kl',
        klinCacheDir: cache.path,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          allOf(contains('incomplete'), contains('klin get')),
        ),
      ),
    );
  });

  test('local github/ directory does not shadow remote import (issue 049)', () {
    final cache = Directory.systemTemp.createTempSync('klin_shadow049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_work049_');
    addTearDown(() => work.deleteSync(recursive: true));
    Directory('${work.path}/github/klin-lang/osa').createSync(recursive: true);
    File('${work.path}/github/klin-lang/osa/bogus.kl').writeAsStringSync('''
module osa
pub fn version(): i32 { return 99 }
''');
    File('${work.path}/app.kl').writeAsStringSync('''
import "github/klin-lang/osa"
fn main() { printf("%d\\n", osa.version()) }
''');
    expect(
      () => loadProject(
        '${work.path}/app.kl',
        klinCacheDir: cache.path,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          contains('klin get'),
        ),
      ),
    );
  });

  test('stdlibCandidatesForInstallRoot Homebrew layout (issue 067)', () {
    final sep = Platform.pathSeparator;
    final roots = ['/opt/homebrew/Cellar/klin/0.1.0', '/repo'];
    final paths = stdlibCandidatesForInstallRoot(roots).toList();
    expect(paths, contains('/opt/homebrew/Cellar/klin/0.1.0${sep}stdlib'));
    expect(
      paths,
      contains('/opt/homebrew/Cellar/klin/0.1.0${sep}share${sep}klin${sep}stdlib'),
    );
    expect(paths, contains('/repo${sep}stdlib'));
  });

  test('klin.mod parse/format round-trip (issue 049)', () {
    final mod = parseKlinMod('klin 1\nrequire github/klin-lang/osa v0.1.0\n');
    expect(mod.requires['github/klin-lang/osa'], 'v0.1.0');
    expect(formatKlinMod(mod), 'klin 1\nrequire github/klin-lang/osa v0.1.0\n');
  });

  test('klin.mod device + parseRemoteAsset (issue 053)', () {
    const devicePath =
        'github/tinygo-org/stm32-svd/svd/stm32f411.svd';
    final mod = parseKlinMod(
      'klin 1\n'
      'require github/klin-lang/osa v0.1.0\n'
      'device $devicePath main\n',
    );
    expect(mod.devices[devicePath], 'main');
    expect(
      formatKlinMod(mod),
      'klin 1\n'
      'require github/klin-lang/osa v0.1.0\n'
      'device $devicePath main\n',
    );

    final asset = parseRemoteAsset('$devicePath@main');
    expect(asset.host, 'github');
    expect(asset.owner, 'tinygo-org');
    expect(asset.repo, 'stm32-svd');
    expect(asset.filePath, 'svd/stm32f411.svd');
    expect(asset.path, devicePath);
    expect(asset.ref, 'main');
    expect(isRemoteDevicePath(devicePath), isTrue);
    expect(isRemoteDevicePath('github/klin-lang/osa'), isFalse);

    expect(
      () => parseRemoteAsset('github/acme/svd/chip.svd'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseRemoteAsset('github/tinygo-org/stm32-svd/../x.svd'),
      throwsA(isA<FormatException>()),
    );
  });

  test(r'$device alias + remote miss suggests klin get (issue 053)', () {
    final dir = Directory('${tmp.path}/svd_device_alias')..createSync();
    File('${dir.path}/tiny.svd').writeAsStringSync('''
<device><peripherals>
  <peripheral><name>RCC</name><baseAddress>0x40023800</baseAddress><registers>
    <register><name>AHB1ENR</name><addressOffset>0x30</addressOffset><fields>
      <field><name>GPIOAEN</name><bitOffset>0</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
</peripherals></device>
''');
    final klPath = '${dir.path}/dev.kl';
    File(klPath).writeAsStringSync(r'''
$device("tiny.svd", "RCC")
fn main() { RCC.AHB1ENR.GPIOAEN.set(1) }
''');
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
    );
    expect(expanded, contains('RCC_AHB1ENR_GPIOAEN_set(1)'));

    final cache = Directory.systemTemp.createTempSync('klin_nocache053_');
    addTearDown(() => cache.deleteSync(recursive: true));
    expect(
      () => preprocess(
        r'''
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC")
fn main() {}
''',
        path: klPath,
        klinCacheDir: cache.path,
      ),
      throwsA(
        predicate(
          (e) =>
              e is PreprocessError && e.toString().contains('klin get'),
        ),
      ),
    );
  });

  test(r'$device prefers local github-shaped path (issue 053)', () {
    final dir = Directory('${tmp.path}/svd_local_github')..createSync();
    final vendored = Directory(
      '${dir.path}/github/tinygo-org/stm32-svd/svd',
    )..createSync(recursive: true);
    File('${vendored.path}/stm32f411.svd').writeAsStringSync('''
<device><peripherals>
  <peripheral><name>RCC</name><baseAddress>0x40023800</baseAddress><registers>
    <register><name>AHB1ENR</name><addressOffset>0x30</addressOffset><fields>
      <field><name>GPIOAEN</name><bitOffset>0</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
</peripherals></device>
''');
    final klPath = '${dir.path}/app.kl';
    File(klPath).writeAsStringSync(r'''
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC")
fn main() { RCC.AHB1ENR.GPIOAEN.set(1) }
''');
    final cache = Directory.systemTemp.createTempSync('klin_local053_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
      klinCacheDir: cache.path,
    );
    expect(expanded, contains('RCC_AHB1ENR_GPIOAEN_set(1)'));
    expect(
      Directory('${cache.path}/asset').existsSync(),
      isFalse,
      reason: 'vendored path must not require asset cache',
    );
  });

  test('klin.lock parse/format round-trip (issue 065)', () {
    const sha = '0123456789abcdef0123456789abcdef01234567';
    const hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final lock = parseKlinLock(
      'klin lock 1\n'
      'github/klin-lang/osa v0.1.0 $sha sha256:$hash\n',
    );
    expect(lock.packages['github/klin-lang/osa']!.version, 'v0.1.0');
    expect(lock.packages['github/klin-lang/osa']!.commit, sha);
    expect(lock.packages['github/klin-lang/osa']!.hash, hash);
    expect(
      formatKlinLock(lock),
      'klin lock 1\n'
      'github/klin-lang/osa v0.1.0 $sha sha256:$hash\n',
    );
  });

  test('cacheSatisfiesRemoteFetch requires lock SHA match (issue 065)', () {
    const pin = 'v0.1.0';
    const sha = '0123456789abcdef0123456789abcdef01234567';
    expect(
      cacheSatisfiesRemoteFetch(
        cachedPin: pin,
        pinValue: pin,
        cachedCommit: sha,
        gitRef: pin,
      ),
      isTrue,
    );
    expect(
      cacheSatisfiesRemoteFetch(
        cachedPin: pin,
        pinValue: pin,
        cachedCommit: sha,
        gitRef: sha,
      ),
      isTrue,
    );
    expect(
      cacheSatisfiesRemoteFetch(
        cachedPin: pin,
        pinValue: pin,
        cachedCommit: sha,
        gitRef: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      isFalse,
    );
    expect(
      cacheSatisfiesRemoteFetch(
        cachedPin: pin,
        pinValue: pin,
        cachedCommit: null,
        gitRef: sha,
      ),
      isFalse,
    );
  });

  test('packageCacheHasRequiredLinkUnits detects missing @[link] .c', () {
    final dir = Directory.systemTemp.createTempSync('klin_link_units_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/usb.kl').writeAsStringSync('''
@[link("usb_cdc_rp.c")]
@[link("-lm")]
fn usb_cdc_out() {}
''');
    expect(packageCacheHasRequiredLinkUnits(dir.path), isFalse);
    File('${dir.path}/usb_cdc_rp.c').writeAsStringSync('void f(void) {}\n');
    expect(packageCacheHasRequiredLinkUnits(dir.path), isTrue);
  });

  test('packageContentHash is stable and order-independent (issue 065)', () {
    final dir = Directory.systemTemp.createTempSync('klin_hash065_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/b.kl').writeAsStringSync('module x\n');
    File('${dir.path}/a.kl').writeAsStringSync('module x\nfn f() {}\n');
    final h1 = packageContentHash(dir.path);
    // Recreate in opposite write order — hash must match.
    final dir2 = Directory.systemTemp.createTempSync('klin_hash065b_');
    addTearDown(() => dir2.deleteSync(recursive: true));
    File('${dir2.path}/a.kl').writeAsStringSync('module x\nfn f() {}\n');
    File('${dir2.path}/b.kl').writeAsStringSync('module x\n');
    expect(packageContentHash(dir2.path), h1);
    File('${dir2.path}/a.kl').writeAsStringSync('module x\nfn f() { }\n');
    expect(packageContentHash(dir2.path), isNot(h1));
  });

  test('remote import rejects path traversal segments (issue 049)', () {
    expect(
      () => parseRemoteImport('github/../../tmp/evil'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseRemoteImport('github/foo/bar/../../x'),
      throwsA(isA<FormatException>()),
    );
  });

  test('isUpgradeTarget / collectOutdated (issue 066)', () async {
    expect(isUpgradeTarget('v0.1.0', 'v0.1.0'), isFalse);
    expect(isUpgradeTarget('v0.1.0', 'v0.2.0'), isTrue);
    expect(isUpgradeTarget('v0.2.0', 'v0.1.0'), isFalse);
    expect(isUpgradeTarget('1.0.0', 'v1.0.1'), isTrue);
    expect(isUpgradeTarget('main', 'v0.1.0'), isTrue);
    expect(isUpgradeTarget('main', 'main'), isFalse);

    final mod = KlinMod(requires: {
      'github/klin-lang/osa': 'v0.1.0',
      'github/acme/lib': 'v1.0.0',
    });
    Future<String> fakeLatest(RemoteImport r) async => switch (r.path) {
          'github/klin-lang/osa' => 'v0.2.0',
          'github/acme/lib' => 'v1.0.0',
          _ => 'v0.0.0',
        };
    final rows = await collectOutdated(mod, resolveLatest: fakeLatest);
    expect(rows.length, 1);
    expect(rows.single.path, 'github/klin-lang/osa');
    expect(rows.single.current, 'v0.1.0');
    expect(rows.single.latest, 'v0.2.0');
    expect(
      formatOutdatedReport(rows),
      'github/klin-lang/osa\tv0.1.0\tv0.2.0\n',
    );
    expect(formatOutdatedReport(const []), 'all packages up to date\n');

    await expectLater(
      collectOutdated(
        mod,
        onlyPaths: ['github/missing/pkg'],
        resolveLatest: fakeLatest,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('golden: async fn emits State + poll (issue 029)', () {
    const source = '''
struct Fut {
  done: i32
}

fn (mut f: Fut) poll(): i32 {
  if f.done != 0 { return 1 }
  f.done = 1
  return 0
}

fn make_fut(): Fut {
  return Fut{ done: 0 }
}

async fn work() {
  make_fut().await
}

fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'async_work.kl');
    expect(c, contains('typedef struct {'));
    expect(c, contains('__stage'));
    expect(c, contains('work_State'));
    expect(c, contains('work_init'));
    expect(c, contains('work_poll'));
    expect(c, contains('work_init_erased'));
    expect(c, contains('work_poll_erased'));
    expect(c, contains('#line '));
    expect(c, contains('case 1:'));
  });

  test('*_test.kl is skipped when loading a package directory (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_skip_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/vec.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 1 }
''');
    File('${dir.path}/geom/geom_test.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 99 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  printf("%d\\n", geom.n())
}
''');
    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    // Duplicate `n` would fail if *_test.kl were loaded.
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('klin_ret_0 = 1'));
    expect(c, isNot(contains('99')));
  });

  test('ambiguous name.kl and name/ directory is an error (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_ambig_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/geom.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 1 }
''');
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/a.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 2 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {}
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(
        predicate(
          (e) =>
              e is FileSystemException &&
              e.message.contains('ambiguous import'),
        ),
      ),
    );
  });

  test('package directory rejects mismatched module name (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_mismatch_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/a.kl').writeAsStringSync('''
module wrong
pub fn n(): i32 { return 1 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  printf("%d\\n", geom.n())
}
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(
        predicate(
          (e) =>
              e is ParseError &&
              e.toString().contains('does not match package'),
        ),
      ),
    );
  });

  test('re-import of a file already in a loaded package is a no-op (issue 047)',
      () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_reimport_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/a.kl').writeAsStringSync('''
module geom
import b
pub fn one(): i32 { return b.two() }
''');
    File('${dir.path}/geom/b.kl').writeAsStringSync('''
module geom
pub fn two(): i32 { return 2 }
''');
    // Mistaken same-package import by file name would resolve to b.kl;
    // must not duplicate geom_two.
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  printf("%d\\n", geom.one())
}
''');
    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program); // would fail on duplicate `two` if re-parsed
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('geom_one'));
    expect(c, contains('geom_two'));
  });

  test('broken same-module sibling fails loudly (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_bad_sib_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
fn main() {}
''');
    File('${dir.path}/other.kl').writeAsStringSync('''
module app
fn broken( {
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(isA<ParseError>()),
    );
  });

  test('shadowed mut receiver emits `.` rather than `->`', () {
    const source = '''
struct Vec2 {
  x: i32
}
fn (mut v: Vec2) bump() {
  let mut v = Vec2{ 1 }
  v.x = v.x + 1
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'shadow.kl');
    expect(c, contains('v.x = (v.x + 1);'));
    expect(c, isNot(contains('v->x')));
  });

  test('parser: `(` on a new line starts a new statement, not a call', () {
    // `&q` ends a line; the next line opens with `(`. Previously this parsed as
    // a call `q(*p)`, swallowing the assignment. It must now be two statements.
    const source = '''
struct P {
  x: i32
}
fn main() {
  let mut q = P{ x: 0 }
  let p: *mut P = &q
  (*p).x = 7
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final main = program.funcs.firstWhere((f) => f.name == 'main');
    // let q, let p, (*p).x = 7  → three statements (no swallowing).
    expect(main.body!.stmts.length, 3);
    expect(main.body!.stmts.last, isA<AssignStmt>());
  });

  test('parser: same-line `(` still parses as a call', () {
    const source = '''
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {
  let x = add(2, 3)
  printf("%d\\n", x)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'call.kl');
    expect(c, contains('add(2, 3)'));
  });

  test('parser: newline before `(` inside open parens still forms a call', () {
    // Go-like: only statement-level newline before `(` breaks a call.
    // Inside an argument list, `bar\\n(y)` must remain a call.
    const source = '''
fn bar(y: i32): i32 { return y }
fn foo(a: i32, b: i32): i32 { return a + b }
fn main() {
  let x = foo(1, bar
(2))
  printf("%d\\n", x)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'nested_call.kl');
    expect(c, contains('foo(1, bar(2))'));
  });

  test('klin fmt: formats associated function declaration (Type.func)', () {
    const ugly =
        'struct Point{x,y:i32}\nfn Point.new(x,y:i32):Point{return Point{x:x,y:y}}\nfn main(){}';
    final once = formatSource(ugly);
    expect(once, contains('fn Point.new(x: i32, y: i32): Point {'));
    expect(formatSource(once), once);
  });

  test('fmt: character literal spelling preserved (issue 081)', () {
    const src = "fn main() {\n    let a: u8 = 'A'\n    let b: u8 = '\\n'\n}";
    expect(formatSource(src), contains("'A'"));
    expect(formatSource(src), contains(r"'\n'"));
  });

  test('checker: array length character `]` and quote escape (issue 081)', () {
    final program = Parser(Lexer(r"""
fn take_brack(xs: [']']u8) {}
fn take_quote(ys: ['\'']u8) {}
fn main() {}
""")
        .tokenize())
        .parse();
    expect(() => Checker().check(program), returnsNormally);
    final c = emitC(program, 't.kl');
    expect(c, contains('uint8_t xs[93]')); // ']' == 93
    expect(c, contains('uint8_t ys[39]')); // '\'' == 39
  });

  test('lexer: `1end` is `1` then ident, not a float exponent (issue 081)', () {
    final tokens = Lexer('1end').tokenize();
    expect(tokens[0].kind, TokenKind.intLit);
    expect(tokens[0].lexeme, '1');
    expect(tokens[1].kind, TokenKind.ident);
    expect(tokens[1].lexeme, 'end');
  });

  test('klin fmt: preserves binary and exponent literals (issue 081)', () {
    const source =
        'fn main() { let a = 0b1010\nlet o = 0o755\nlet b = 1.5e-3\nlet c = 1e9 }';
    final once = formatSource(source);
    expect(once, contains('0b1010'));
    expect(once, contains('0o755'));
    expect(once, contains('1.5e-3'));
    expect(once, contains('1e9'));
    expect(formatSource(once), once);
  });

  test('return plus a next-line call does not consume the statement', () {
    const source = '''
fn main() {
  return
  puts("after")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    final body = program.funcs.single.body!.stmts;
    expect(body.length, 2);
    expect(body[0], isA<ReturnStmt>());
    expect((body[0] as ReturnStmt).value, isNull);
    expect(body[1], isA<CallStmt>());
  });

  test('implicit array-to-slice conversion emits a slice header', () {
    const source = '''
fn sum(xs: []i32): i32 { return xs.len }
fn main() {
  let buf: [2]i32 = [1, 2]
  printf("%d\\n", sum(buf))
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'coerce.kl');
    expect(c, contains('(klin_slice_i32){ buf, 2 }'));
  });

  test('hexadecimal literal accepts underscores', () {
    const source = '''
fn main() {
  let address: u32 = 0x4000_1000
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    expect(emitC(program, 'hex.kl'), contains('0x40001000'));
  });

  test('codename emits a global C symbol', () {
    const source = '''
@[codename("SysTick_Handler")]
fn tick() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'tick.kl');
    expect(c, contains('void SysTick_Handler(void);'));
    expect(c, contains('void SysTick_Handler(void) {'));
    expect(c, isNot(contains('static void SysTick_Handler')));
  });

  test('isr("…") sugar emits a global C vector symbol (issue 030)', () {
    const source = '''
@[isr("SysTick_Handler")]
fn tick() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'isr.kl');
    expect(c, contains('void SysTick_Handler(void);'));
    expect(c, contains('void SysTick_Handler(void) {'));
    expect(c, isNot(contains('static void SysTick_Handler')));
  });

  test('isr + codename emits a global C vector symbol (issue 030)', () {
    const source = '''
@[isr, codename("TIM2_IRQHandler")]
fn on_tim2() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'isr2.kl');
    expect(c, contains('void TIM2_IRQHandler(void);'));
    expect(c, isNot(contains('static void TIM2_IRQHandler')));
  });

  test('isr without vector name is a checker error', () {
    const source = '''
@[isr]
fn tick() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('isr'),
      )),
    );
  });

  test('isr with parameters is a checker error', () {
    const source = '''
@[isr("SysTick_Handler")]
fn tick(x: i32) {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError && e.toString().contains('no parameters'),
      )),
    );
  });

  test('isr with non-void return is a checker error', () {
    const source = '''
@[isr("SysTick_Handler")]
fn tick(): i32 { return 0 }
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('void'),
      )),
    );
  });

  test('isr name conflicting with codename is a checker error', () {
    const source = '''
@[isr("SysTick_Handler"), codename("Other_Handler")]
fn tick() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('conflicts'),
      )),
    );
  });

  test('cexport + codename emits a global C symbol (issue 045)', () {
    const source = '''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {
  printf("%d\\n", add(2, 3))
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'exp.kl');
    expect(c, contains('int32_t klin_add(int32_t a, int32_t b);'));
    expect(c, contains('int32_t klin_add(int32_t a, int32_t b) {'));
    expect(c, isNot(contains('static int32_t klin_add')));
  });

  test('cexport without codename is a checker error', () {
    const source = '''
@[cexport]
fn add(a: i32, b: i32): i32 { return a + b }
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('codename'),
      )),
    );
  });

  test('cexport cannot combine with cimport', () {
    const source = '''
@[cexport, cimport, codename("x")]
fn x()
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('cimport') &&
            e.toString().contains('cexport'),
      )),
    );
  });

  test('cexport on main is a checker error', () {
    const source = '''
@[cexport, codename("not_really_main")]
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('main'),
      )),
    );
  });

  test('emitH writes prototypes for cexport (issue 046)', () {
    const source = '''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final h = emitH(program, 'lib.kl');
    expect(h, contains('#ifndef KLIN_LIB_H'));
    expect(h, contains('#include <stdint.h>'));
    expect(h, contains('int32_t klin_add(int32_t a, int32_t b);'));
    expect(h, isNot(contains('main')));
    expect(h, contains('#endif /* KLIN_LIB_H */'));
  });

  test('emitH closes nested struct deps regardless of decl order (issue 046)', () {
    // Signature only mentions Outer; Inner is two levels down. One pass over
    // program.structs (decl order Inner → Mid → Outer) used to miss Inner.
    const source = '''
struct Inner {
  x: i32
}
struct Mid {
  inner: Inner
}
struct Outer {
  mid: Mid
}
@[cexport, codename("klin_take_outer")]
fn take_outer(o: Outer): i32 {
  return o.mid.inner.x
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final h = emitH(program, 'nest.kl');
    expect(h, contains('Inner'));
    expect(h, contains('Mid'));
    expect(h, contains('Outer'));
    expect(h.indexOf('Inner'), lessThan(h.indexOf('Mid')));
    expect(h.indexOf('Mid'), lessThan(h.indexOf('Outer')));
    expect(h, contains('klin_take_outer'));
  });

  test('emitC emits nested struct typedefs before dependents', () {
    // Declaration order Outer → Mid → Inner must still typedef Inner first.
    const source = '''
struct Outer {
  mid: Mid
}
struct Mid {
  inner: Inner
}
struct Inner {
  x: i32
}
fn main() {
  let o = Outer{ mid: Mid{ inner: Inner{ x: 1 } } }
  let _ = o.mid.inner.x
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'struct_order.kl');
    // Typedef close lines: "} <module>_Inner;" — use the closing tag to avoid
    // matching field type mentions inside later structs.
    final innerTd = c.indexOf('} Inner;');
    final midTd = c.indexOf('} Mid;');
    final outerTd = c.indexOf('} Outer;');
    expect(innerTd, greaterThanOrEqualTo(0));
    expect(midTd, greaterThanOrEqualTo(0));
    expect(outerTd, greaterThanOrEqualTo(0));
    expect(innerTd, lessThan(midTd));
    expect(midTd, lessThan(outerTd));
  });

  test('cimport emits a declaration and checks its signature', () {
    const source = '''
@[cimport, codename("pin_set")]
fn set_pin(value: u32)
fn main() {
  set_pin(1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'ffi.kl');
    expect(c, contains('uint32_t value'));
    expect(c, contains('void pin_set(uint32_t value);'));
    expect(c, isNot(contains('void pin_set(uint32_t value) {')));

    const badSource = '''
@[cimport]
fn set_pin(value: u32)
fn main() {
  set_pin()
}
''';
    final bad = Parser(Lexer(badSource).tokenize()).parse();
    expect(
      () => Checker().check(bad),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('expects 1 arguments'),
      )),
    );
  });

  test(
      'cimport with a body and a bodyless non-cimport function are checker errors',
      () {
    final pos = const SourcePos(1, 1);
    final main = FuncDecl(
      name: 'main',
      receiver: null,
      params: [],
      returnTypeName: null,
      body: Block([], pos),
      pos: pos,
    );
    final importedWithBody = FuncDecl(
      name: 'ffi',
      receiver: null,
      params: [],
      returnTypeName: null,
      body: Block([], pos),
      attrs: [Attr('cimport', null, pos)],
      pos: pos,
    );
    expect(
      () => Checker().check(Program([], [importedWithBody, main], pos)),
      throwsA(isA<CheckError>()),
    );
    final missingBody = FuncDecl(
      name: 'missing',
      receiver: null,
      params: [],
      returnTypeName: null,
      body: null,
      pos: pos,
    );
    expect(
      () => Checker().check(Program([], [missingBody, main], pos)),
      throwsA(isA<CheckError>()),
    );
  });

  test('asm emits asm volatile without stdio', () {
    const source = '''
fn main() {
  asm("wfi")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'asm.kl');
    expect(c, contains('asm volatile("wfi");'));
    expect(c, isNot(contains('#include <stdio.h>')));
  });

  test('buildCcArgs resolves @[link] paths and CLI -l/-L', () {
    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
          attrs: [
            Attr('link', 'libadd.a', pos),
            Attr('link', '-lm', pos),
          ],
          sourcePath: '${tmp.path}/main.kl',
        ),
      ],
      pos,
    );
    final dir = tmp.path;
    File('$dir/libadd.a').writeAsStringSync('');
    final args = buildCcArgs(
      cPath: 'out/x.c',
      binPath: 'out/x',
      program: program,
      sourceDir: dir,
      cliLibs: const ['m'],
      cliLibDirs: const ['/opt/lib'],
    );
    expect(args.first, 'out/x.c');
    expect(args, contains('$dir/libadd.a'));
    final lOpt = args.indexOf('-L/opt/lib');
    final lm = args.indexOf('-lm');
    expect(lOpt, greaterThan(0));
    expect(lm, greaterThan(lOpt));
    expect(args.where((a) => a == '-lm').length, 2);
    expect(args.sublist(args.length - 2), ['-o', 'out/x']);
  });

  test('buildCcArgs puts CLI -L before @[link("-l…")]', () {
    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
          attrs: [Attr('link', '-lfoo', pos)],
        ),
      ],
      pos,
    );
    final args = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
      cliLibDirs: const ['/libs'],
    );
    expect(args.indexOf('-L/libs'), lessThan(args.indexOf('-lfoo')));
  });

  test('buildCcArgs -g / debug passes host -g (issue 088)', () {
    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
        ),
      ],
      pos,
    );
    final plain = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
    );
    expect(plain, isNot(contains('-g')));
    final debug = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
      debug: true,
    );
    expect(debug, contains('-g'));
    expect(debug.indexOf('-g'), lessThan(debug.indexOf('-o')));
  });

  test('normalizeCcOptFlag and buildCcArgs -O / --opt', () {
    expect(normalizeCcOptFlag('0'), '-O0');
    expect(normalizeCcOptFlag('2'), '-O2');
    expect(normalizeCcOptFlag('O3'), '-O3');
    expect(normalizeCcOptFlag('-Os'), '-Os');
    expect(normalizeCcOptFlag('z'), '-Oz');
    expect(normalizeCcOptFlag('Oz'), '-Oz');
    expect(normalizeCcOptFlag('S'), '-Os');
    expect(normalizeCcOptFlag('9'), isNull);
    expect(normalizeCcOptFlag('fast'), isNull);

    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
        ),
      ],
      pos,
    );
    final plain = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
    );
    expect(plain.any((a) => a.startsWith('-O')), isFalse);
    final opt2 = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
      debug: true,
      opt: normalizeCcOptFlag('2'),
    );
    expect(opt2, contains('-g'));
    expect(opt2, contains('-O2'));
    expect(opt2.indexOf('-g'), lessThan(opt2.indexOf('-O2')));
    expect(opt2.indexOf('-O2'), lessThan(opt2.indexOf('-o')));
  });

  test('cheader cimport skips C prototype emission', () {
    const source = '''
@[cinclude("regs.h")]
@[cimport, cheader, codename("pin_toggle")]
fn pin_toggle()
fn main() {
  pin_toggle()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'hdr.kl');
    expect(c, contains('#include "regs.h"'));
    expect(c, isNot(contains('void pin_toggle(void);')));
    expect(c, contains('pin_toggle();'));
  });

  test('host builtins puts/printf remain without cimport', () {
    const source = '''
fn main() {
  puts("hi")
  printf("%d\\n", 1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
  });

}
