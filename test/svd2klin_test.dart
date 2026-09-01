@Tags(['unit'])
library;

import 'dart:io';

import 'package:klin/svd/emit.dart';
import 'package:klin/svd/parse.dart';
import 'package:klin/svd/svd2klin.dart';
import 'package:test/test.dart';

void main() {
  test('parser expands fields and resolves derived enum values', () {
    const svd = '''
<device><peripherals>
  <peripheral><name>RCC</name><baseAddress>0x40023800</baseAddress><registers>
    <register><name>AHB1ENR</name><addressOffset>0x30</addressOffset><fields>
      <field><name>GPIOAEN</name><bitOffset>0</bitOffset><bitWidth>1</bitWidth>
        <enumeratedValues><enumeratedValue><name>Off</name><value>0</value></enumeratedValue><enumeratedValue><name>On</name><value>1</value></enumeratedValue></enumeratedValues>
      </field>
    </fields></register>
  </registers></peripheral>
  <peripheral><name>GPIOA</name><baseAddress>0x40020000</baseAddress><registers>
    <register><name>MODER</name><addressOffset>0</addressOffset><fields>
      <field><name>MODER%s</name><dim>16</dim><dimIncrement>0x2</dimIncrement><dimIndex>0-15</dimIndex><bitOffset>0</bitOffset><bitWidth>2</bitWidth>
        <enumeratedValues><enumeratedValue><name>Output</name><value>1</value></enumeratedValue></enumeratedValues>
      </field>
    </fields></register>
    <register><name>ODR</name><addressOffset>0x14</addressOffset><fields>
      <field derivedFrom="GPIOA.MODER.MODER%s"><name>ODR%s</name><dim>16</dim><dimIncrement>1</dimIncrement><dimIndex>0-15</dimIndex><bitOffset>0</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
</peripherals></device>''';

    final device = parseSvd(svd, peripherals: {'RCC', 'GPIOA'});
    final gpioa = device.peripherals.singleWhere((p) => p.name == 'GPIOA');
    final moder5 = gpioa.registers
        .singleWhere((r) => r.name == 'MODER')
        .fields
        .singleWhere((f) => f.name == 'MODER5');
    final odr5 = gpioa.registers
        .singleWhere((r) => r.name == 'ODR')
        .fields
        .singleWhere((f) => f.name == 'ODR5');
    expect(moder5.bitOffset, 10);
    expect(odr5.enums.single.name, 'Output');

    final output = emitSvd(
      device,
      headerGuard: 'TEST_REGS_H',
      includeName: 'test_regs.h',
    );
    expect(output.header, contains('0x40023830u'));
    expect(output.header, contains('(3u << 10)'));
    expect(output.header, contains('(1u << 5)'));
    expect(output.header, contains('#define GPIOA_MODER_MODER5_Output 1u'));
  });

  test('real STM32F411 generator emits RCC, GPIOA and synthetic SysTick', () {
    final generated = generateFromSvdFile(
      'third_party/svd/stm32f411.svd',
      peripherals: {'RCC', 'GPIOA', 'STK'},
    );
    expect(generated.header, contains('RCC_AHB1ENR_GPIOAEN_set'));
    expect(generated.header, contains('GPIOA_MODER_MODER5_write'));
    expect(generated.header, contains('STK_CSR_ENABLE_set'));
    expect(generated.klin, contains('@[cinclude("stm32f411_regs.h")]'));
  });

  test('register derivedFrom copies fields; write-only avoids RMW', () {
    const svd = '''
<device><peripherals>
  <peripheral><name>GPIOA</name><baseAddress>0x40020000</baseAddress><registers>
    <register><name>ODR</name><addressOffset>0x14</addressOffset><access>read-write</access><fields>
      <field><name>ODR5</name><bitOffset>5</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
    <register><name>BSRR</name><addressOffset>0x18</addressOffset><access>write-only</access><fields>
      <field><name>BS5</name><bitOffset>5</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
  <peripheral><name>GPIOB</name><baseAddress>0x40020400</baseAddress><registers>
    <register derivedFrom="GPIOA.ODR"><name>ODR</name><addressOffset>0x14</addressOffset></register>
  </registers></peripheral>
</peripherals></device>''';
    final device = parseSvd(svd);
    final gpiobOdr = device.peripherals
        .singleWhere((p) => p.name == 'GPIOB')
        .registers
        .singleWhere((r) => r.name == 'ODR');
    expect(gpiobOdr.fields.single.name, 'ODR5');
    expect(device.peripherals.any((p) => p.name == 'STK'), isTrue);

    final output = emitSvd(
      device,
      headerGuard: 'WO_H',
      includeName: 'wo.h',
    );
    expect(output.header, contains('GPIOA_BSRR_BS5_write'));
    expect(output.header, isNot(contains('GPIOA_BSRR_BS5_toggle')));
    expect(
      output.header,
      contains('*r = ((v << 5) & (1u << 5));'),
    );
    expect(output.header, isNot(contains('GPIOA_BSRR_BS5_write(uint32_t v) {\n  volatile uint32_t *r = (volatile uint32_t *)(0x40020018u);\n  uint32_t m =')));
  });

  test('CLI writes generated header and Klin declarations', () async {
    final temp = await Directory.systemTemp.createTemp('klin_svd_');
    addTearDown(() => temp.delete(recursive: true));
    final header = '${temp.path}/regs.h';
    final klin = '${temp.path}/regs.kl';
    final result = await Process.run('dart', [
      'run',
      'bin/svd2klin.dart',
      '--svd',
      'third_party/svd/stm32f411.svd',
      '--out-h',
      header,
      '--out-kl',
      klin,
      '--peripherals',
      'RCC,GPIOA,STK',
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(await File(header).readAsString(), contains('STK_RVR_RELOAD_write'));
    expect(await File(klin).readAsString(), contains('GPIOA_ODR_ODR5_toggle'));
  });
}
