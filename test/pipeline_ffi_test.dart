@Tags(['e2e'])
library;

import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/link_args.dart';
import 'package:klin/project.dart';
import 'package:test/test.dart';

import 'support/compile_and_run.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('C caller can link against cexport symbol (issue 045)', () async {
    final kl = File('${tmp.path}/lib_add.kl');
    await kl.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {}
''');
    final program = loadProject(kl.path);
    Checker().check(program);
    // Klin requires `main`; rename it so the C caller owns the entry point.
    var cSource = emitC(program, kl.path);
    cSource = cSource.replaceAll('int main(void)', 'static int klin_lib_main(void)');
    final cPath = '${tmp.path}/lib_add.c';
    await File(cPath).writeAsString(cSource);

    final caller = File('${tmp.path}/caller.c');
    await caller.writeAsString('''
#include <stdint.h>
#include <stdio.h>
int32_t klin_add(int32_t a, int32_t b);
int main(void) {
  printf("%d\\n", (int)klin_add(2, 3));
  return 0;
}
''');
    final bin = '${tmp.path}/cexport_bin';
    final compile = await Process.run('gcc', [
      caller.path,
      cPath,
      '-o',
      bin,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stderr}${compile.stdout}');
    final run = await Process.run(bin, []);
    expect(run.exitCode, 0, reason: run.stderr);
    expect(run.stdout, '5\n');
  });

  test('C caller can #include emitH header (issue 046)', () async {
    final kl = File('${tmp.path}/lib_add_h.kl');
    await kl.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {}
''');
    final program = loadProject(kl.path);
    Checker().check(program);
    var cSource = emitC(program, kl.path);
    cSource =
        cSource.replaceAll('int main(void)', 'static int klin_lib_main(void)');
    final cPath = '${tmp.path}/lib_add_h.c';
    final hPath = '${tmp.path}/lib_add_h.h';
    await File(cPath).writeAsString(cSource);
    await File(hPath).writeAsString(emitH(program, kl.path));

    final caller = File('${tmp.path}/caller_h.c');
    await caller.writeAsString('''
#include <stdio.h>
#include "lib_add_h.h"
int main(void) {
  printf("%d\\n", (int)klin_add(2, 3));
  return 0;
}
''');
    final bin = '${tmp.path}/cexport_h_bin';
    final compile = await Process.run('gcc', [
      caller.path,
      cPath,
      '-I',
      tmp.path,
      '-o',
      bin,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stderr}${compile.stdout}');
    final run = await Process.run(bin, []);
    expect(run.exitCode, 0, reason: run.stderr);
    expect(run.stdout, '5\n');
  });

  test('klin run links @[cimport] against a static archive (issue 021)', () async {
    final addC = File('${tmp.path}/add.c');
    await addC.writeAsString('''
int add(int a, int b) { return a + b; }
''');
    final obj = '${tmp.path}/add.o';
    final archive = '${tmp.path}/libadd.a';
    final ccObj = await Process.run('gcc', ['-c', addC.path, '-o', obj]);
    expect(ccObj.exitCode, 0, reason: ccObj.stderr);
    final ar = await Process.run('ar', ['rcs', archive, obj]);
    expect(ar.exitCode, 0, reason: ar.stderr);

    final kl = File('${tmp.path}/use_add.kl');
    await kl.writeAsString('''
@[link("libadd.a")]
@[cimport, codename("add")]
fn add(a: i32, b: i32): i32

fn main() {
  printf("%d\\n", add(2, 3))
}
''');
    final result = await compileAndRun(kl.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '5\n');
  });

  test('klin run links @[cimport] against an ASM unit (issue 022)', () async {
    final asm = File('${tmp.path}/add.S');
    await asm.writeAsString(r'''
#if defined(__APPLE__)
#  define ASM_ADD_SYM _asm_add
#else
#  define ASM_ADD_SYM asm_add
#endif
.globl ASM_ADD_SYM
ASM_ADD_SYM:
#if defined(__aarch64__) || defined(__arm64__)
        add     w0, w0, w1
        ret
#elif defined(__x86_64__)
        movl    %edi, %eax
        addl    %esi, %eax
        ret
#else
#  error unsupported arch
#endif
''');
    final kl = File('${tmp.path}/use_asm.kl');
    await kl.writeAsString('''
@[link("add.S")]
@[cimport, codename("asm_add")]
fn asm_add(a: i32, b: i32): i32

fn main() {
  printf("%d\\n", asm_add(2, 3))
}
''');
    final result = await compileAndRun(kl.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '5\n');
  });

  test('klin run -l/-L links a named library (issue 021)', () async {
    final addC = File('${tmp.path}/mylib.c');
    await addC.writeAsString('''
int mylib_answer(void) { return 42; }
''');
    final obj = '${tmp.path}/mylib.o';
    final archive = '${tmp.path}/libmylib.a';
    expect(
      (await Process.run('gcc', ['-c', addC.path, '-o', obj])).exitCode,
      0,
    );
    expect((await Process.run('ar', ['rcs', archive, obj])).exitCode, 0);

    final kl = File('${tmp.path}/use_mylib.kl');
    await kl.writeAsString('''
@[cimport, codename("mylib_answer")]
fn answer(): i32

fn main() {
  printf("%d\\n", answer())
}
''');
    final program = loadProject(kl.path);
    Checker().check(program);
    final cPath = '${tmp.path}/use_mylib.c';
    final binPath = '${tmp.path}/use_mylib';
    await File(cPath).writeAsString(emitC(program, kl.path));
    final args = buildCcArgs(
      cPath: cPath,
      binPath: binPath,
      program: program,
      sourceDir: tmp.path,
      cliLibs: const ['mylib'],
      cliLibDirs: [tmp.path],
    );
    final compile = await Process.run('gcc', args);
    expect(compile.exitCode, 0, reason: '${compile.stderr}${compile.stdout}');
    final run = await Process.run(binPath, []);
    expect(run.exitCode, 0, reason: run.stderr);
    expect(run.stdout, '42\n');
  });

  test('STM32 example builds and exports SysTick_Handler', () async {
    final compiler = await Process.run(
      'sh',
      ['-c', 'command -v arm-none-eabi-gcc'],
    );
    if (compiler.exitCode != 0) return;

    const example = 'examples/stm32/blink_f411';
    addTearDown(
        () => Process.run('make', ['clean'], workingDirectory: example));
    final registers = await Process.run(
      'dart',
      [
        'run',
        'bin/svd2klin.dart',
        '--svd',
        'third_party/svd/stm32f411.svd',
        '--out-h',
        '$example/stm32f411_regs.h',
        '--out-kl',
        '$example/stm32f411_regs.kl',
        '--peripherals',
        'RCC,GPIOA,STK',
      ],
    );
    expect(registers.exitCode, 0, reason: registers.stderr.toString());
    final build = await Process.run('make', [], workingDirectory: example);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');

    final nm = await Process.run(
      'arm-none-eabi-nm',
      ['main.elf'],
      workingDirectory: example,
    );
    expect(nm.exitCode, 0, reason: nm.stderr.toString());
    expect(nm.stdout.toString(), contains('SysTick_Handler'));

    final objdump = await Process.run(
      'arm-none-eabi-objdump',
      ['-d', 'main.elf'],
      workingDirectory: example,
    );
    expect(objdump.exitCode, 0, reason: objdump.stderr.toString());
    final disasm = objdump.stdout.toString();
    expect(disasm, contains('<SysTick_Handler>'));
    // Fluent API must lower to static inline MMIO — no bl to accessors (027).
    final accessorBl = RegExp(
      r'bl\s+[0-9a-f]+\s+<(?:RCC_|GPIOA_|STK_)[^>]+>',
    );
    expect(accessorBl.hasMatch(disasm), isFalse, reason: disasm);
  });

}
