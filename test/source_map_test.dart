@Tags(['unit'])
library;

import 'dart:io';

import 'package:klin/analyze.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/source_map.dart';
import 'package:test/test.dart';

void main() {
  group('SourceMap', () {
    test(r'toExpanded maps inside $name(…) call into the expansion', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let a: i32 = 1
}
''';
      final pp = preprocessWithMap(source, path: 't.kl');
      expect(pp.map, isNotNull);
      final map = pp.map!;
      final call = source.indexOf(r'$point');
      final v = source.indexOf('Vec2i', call);
      final exp = map.toExpanded(positionOf(source, v));
      final expOff = offsetOf(pp.text, exp);
      final mainOff = pp.text.indexOf('fn main');
      expect(mainOff, greaterThan(0));
      // Must land in the expansion (`struct Vec2i`), not on `fn main`.
      expect(expOff, lessThan(mainOff));
      expect(pp.text.substring(expOff, mainOff), contains('struct Vec2i'));
    });

    test('toOriginal remaps expanded identity text', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let a: i32 = 1
}
''';
      final pp = preprocessWithMap(source, path: 't.kl');
      final map = pp.map!;
      final aInExp = pp.text.indexOf('let a');
      final orig = map.toOriginal(positionOf(pp.text, aInExp));
      expect(source.substring(offsetOf(source, orig)), startsWith('let a'));
    });

    test(r'analyze remaps diagnostic after $fn via source map', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let bad: NoSuch = 1
}
''';
      final result = analyzeSource(path: 't.kl', source: source);
      expect(result.sourceMap, isNotNull);
      expect(result.positionsSkewed, isFalse);
      expect(result.diagnostics.single.pos.line, 6);
    });

    test(r'$device fluent rewrite keeps SourceMap (issue 091)', () {
      final dir = Directory.systemTemp.createTempSync('klin_svd_map_');
      addTearDown(() => dir.deleteSync(recursive: true));

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
      final source = r'''
$device("tiny.svd", "RCC,GPIOA")
fn main(): void {
  RCC.AHB1ENR.GPIOAEN.set(1)
  GPIOA.MODER.MODER5.write(.Output)
  GPIOA.ODR.ODR5.toggle()
  // keep GPIOA.MODER.MODER5.write(.Output)
  puts("GPIOA.MODER.MODER5.write(.Output)")
  let bad: NoSuch = 1
}
''';
      File(klPath).writeAsStringSync(source);

      final pp = preprocessWithMap(source, path: klPath);
      expect(pp.map, isNotNull, reason: 'fluent must not drop the map');
      expect(pp.map!.origOfExpanded.length, pp.text.length);
      expect(pp.text, contains('GPIOA_MODER_MODER5_write(1)'));
      expect(pp.text, contains('// keep GPIOA.MODER.MODER5.write(.Output)'));
      expect(pp.text, contains('puts("GPIOA.MODER.MODER5.write(.Output)")'));
      // Code (not comment/string) must be rewritten.
      expect(
        pp.text.split('\n').where((l) => l.contains('GPIOA.MODER.MODER5')).length,
        2,
        reason: 'only comment + string keep dotted fluent form',
      );
      // Expanded fluent call maps back near the editor fluent site.
      final writeInExp = pp.text.indexOf('GPIOA_MODER_MODER5_write');
      expect(writeInExp, greaterThan(0));
      final orig = pp.map!.toOriginal(positionOf(pp.text, writeInExp));
      final origOff = offsetOf(source, orig);
      expect(
        source.substring(origOff),
        contains('GPIOA.MODER.MODER5.write'),
      );

      final result = analyzeSource(path: klPath, source: source);
      expect(result.positionsSkewed, isFalse);
      expect(result.sourceMap, isNotNull);
      expect(result.diagnostics, isNotEmpty);
      final badLine =
          source.split('\n').indexWhere((l) => l.contains('NoSuch')) + 1;
      expect(
        result.diagnostics.any((d) => d.pos.line == badLine),
        isTrue,
        reason: 'check error must remap to editor line with NoSuch, not 1:1',
      );
    });

    test(r'fluent PreprocessError remaps to editor coords', () {
      final dir = Directory.systemTemp.createTempSync('klin_svd_err_');
      addTearDown(() => dir.deleteSync(recursive: true));

      File('${dir.path}/tiny.svd').writeAsStringSync('''
<device><peripherals>
  <peripheral><name>GPIOA</name><baseAddress>0x40020000</baseAddress><registers>
    <register><name>ODR</name><addressOffset>0x14</addressOffset><fields>
      <field><name>ODR5</name><bitOffset>5</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
</peripherals></device>
''');
      final klPath = '${dir.path}/bad.kl';
      final source = r'''
$device("tiny.svd", "GPIOA")
fn main(): void {
  GPIOA.ODR.ODR5.toggle(1)
}
''';
      File(klPath).writeAsStringSync(source);

      final result = analyzeSource(path: klPath, source: source);
      expect(result.diagnostics, isNotEmpty);
      final toggleLine =
          source.split('\n').indexWhere((l) => l.contains('toggle')) + 1;
      expect(toggleLine, greaterThan(1));
      final d = result.diagnostics.single;
      expect(d.message, contains('takes no arguments'));
      expect(
        d.pos.line,
        toggleLine,
        reason: r'must not point into the mid-text $device expansion',
      );
    });
  });
}
