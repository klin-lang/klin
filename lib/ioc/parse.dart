/// Narrow CubeMX `.ioc` pinout parser (issue 074).
///
/// Reads only pin labels → port/pin. Ignores clocks, IP blocks, HAL, and
/// code-generation settings.

/// One labeled GPIO from an `.ioc` file.
final class IocPin {
  /// Klin-safe identifier (e.g. `LD2`, `B1`).
  final String name;

  /// Port letter `A`…`K` (uppercase).
  final String port;

  /// Pin number within the port (0–15).
  final int pin;

  /// Raw Cube `GPIO_Label` text.
  final String label;

  /// Cube pin key (e.g. `PA5`, `PC13-ANTI_TAMP`).
  final String cubePin;

  const IocPin({
    required this.name,
    required this.port,
    required this.pin,
    required this.label,
    required this.cubePin,
  });

  /// AHB1-style port index matching `machine_stm32.Port` (A=0 … E=4, H=7).
  int get portIndex {
    final c = port.codeUnitAt(0);
    if (c >= 0x41 && c <= 0x45) return c - 0x41; // A..E
    if (port == 'H') return 7;
    // F, G, I, J, K — sequential after E is uncommon on F411; keep letter-A.
    return c - 0x41;
  }
}

/// Parsed pinout subset of a CubeMX `.ioc`.
final class IocPinout {
  final List<IocPin> pins;

  const IocPinout({required this.pins});
}

final class IocParseError implements Exception {
  final String message;
  IocParseError(this.message);
  @override
  String toString() => 'IocParseError: $message';
}

/// Parse CubeMX `.ioc` text into labeled pins only.
IocPinout parseIoc(String content) {
  final kv = <String, String>{};
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
      continue;
    }
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    final value = line.substring(eq + 1).trim();
    kv[key] = value;
  }

  final labeled = <String, String>{}; // cubePin → label
  for (final entry in kv.entries) {
    if (!entry.key.endsWith('.GPIO_Label')) continue;
    final cubePin = entry.key.substring(
      0,
      entry.key.length - '.GPIO_Label'.length,
    );
    if (cubePin.isEmpty) continue;
    labeled[cubePin] = entry.value;
  }

  final pins = <IocPin>[];
  final seenNames = <String>{};
  for (final entry in labeled.entries) {
    final cubePin = entry.key;
    final label = entry.value;
    final phys = _physicalPin(cubePin);
    if (phys == null) continue; // VP_SYS_… / non-GPIO
    final name = _sanitizeLabel(label);
    if (name == null) continue;
    // Skip debug / oscillator noise unless the label is a user LED/button style
    // short name — already sanitized; drop SYS/RCC-ish cube signals.
    final signal = kv['$cubePin.Signal'] ?? '';
    if (_isNoiseSignal(signal) && !_looksUserLabel(label)) continue;

    if (!seenNames.add(name)) {
      throw IocParseError('duplicate pin label `$name` in .ioc');
    }
    pins.add(
      IocPin(
        name: name,
        port: phys.$1,
        pin: phys.$2,
        label: label,
        cubePin: cubePin,
      ),
    );
  }

  pins.sort((a, b) => a.name.compareTo(b.name));
  return IocPinout(pins: pins);
}

(String, int)? _physicalPin(String cubePin) {
  // PA5, PC13-ANTI_TAMP, PH0 - OSC_IN
  final m = RegExp(r'^P([A-K])(\d{1,2})\b').firstMatch(cubePin);
  if (m == null) return null;
  final port = m.group(1)!;
  final pin = int.parse(m.group(2)!);
  if (pin < 0 || pin > 15) return null;
  return (port, pin);
}

String? _sanitizeLabel(String label) {
  // "LD2 [Green Led]" → LD2; "B1 [Blue PushButton]" → B1
  var s = label.trim();
  final bracket = s.indexOf('[');
  if (bracket >= 0) s = s.substring(0, bracket).trim();
  if (s.isEmpty) return null;
  // Keep leading identifier chars.
  final m = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)').firstMatch(s);
  if (m == null) return null;
  var name = m.group(1)!;
  // Klin idents: avoid clashing with single-letter ports accidentally — OK.
  if (name == 'main') name = 'board_main';
  return name;
}

bool _isNoiseSignal(String signal) {
  if (signal.isEmpty) return false;
  final u = signal.toUpperCase();
  return u.startsWith('SYS_') ||
      u.startsWith('RCC_') ||
      u.contains('JTMS') ||
      u.contains('JTCK') ||
      u.contains('JTDO') ||
      u.contains('SWCLK') ||
      u.contains('SWDIO') ||
      u.contains('TRACESWO') ||
      u.contains('OSC');
}

bool _looksUserLabel(String label) {
  final s = label.trim().toUpperCase();
  return s.startsWith('LD') ||
      s.startsWith('LED') ||
      s.startsWith('B1') ||
      s.startsWith('BTN') ||
      s.startsWith('USER') ||
      s.contains('LED') ||
      s.contains('BUTTON');
}
