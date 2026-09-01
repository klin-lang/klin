@Tags(['unit'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('editors/vscode TextMate pack (issue 093)', () {
    final root = Directory.current.path;
    final grammarPath = '$root/editors/vscode/syntaxes/klin.tmLanguage.json';
    final packagePath = '$root/editors/vscode/package.json';
    final langConfigPath = '$root/editors/vscode/language-configuration.json';

    test('klin.tmLanguage.json is valid JSON with expected scopes', () {
      final raw = File(grammarPath).readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['scopeName'], 'source.klin');
      expect(json['name'], 'Klin');
      final patterns = json['patterns'] as List<dynamic>;
      expect(patterns, isNotEmpty);
      final repo = json['repository'] as Map<String, dynamic>;
      expect(repo.keys, containsAll(['comments', 'strings', 'keywords', 'types']));
    });

    test('package.json contributes klin language and grammar', () {
      final json =
          jsonDecode(File(packagePath).readAsStringSync()) as Map<String, dynamic>;
      final contributes = json['contributes'] as Map<String, dynamic>;
      final languages = contributes['languages'] as List<dynamic>;
      expect(
        languages.any((l) => (l as Map)['id'] == 'klin'),
        isTrue,
      );
      final grammars = contributes['grammars'] as List<dynamic>;
      expect(
        grammars.any((g) => (g as Map)['scopeName'] == 'source.klin'),
        isTrue,
      );
    });

    test('language-configuration uses // line comments only', () {
      final json = jsonDecode(File(langConfigPath).readAsStringSync())
          as Map<String, dynamic>;
      final comments = json['comments'] as Map<String, dynamic>;
      expect(comments['lineComment'], '//');
      expect(comments.containsKey('blockComment'), isFalse);
    });

    test('grammar mentions core Klin keywords and primitives', () {
      final raw = File(grammarPath).readAsStringSync();
      for (final kw in ['fn', 'async', 'await', 'match', 'pick', 'defer']) {
        expect(raw, contains(kw), reason: 'keyword `$kw`');
      }
      for (final t in ['i32', 'void', 'str', 'bool']) {
        expect(raw, contains(t), reason: 'type `$t`');
      }
    });

    test('operators list longer tokens before shorter prefixes', () {
      final json = jsonDecode(File(grammarPath).readAsStringSync())
          as Map<String, dynamic>;
      final repo = json['repository'] as Map<String, dynamic>;
      final ops = repo['operators'] as Map<String, dynamic>;
      final patterns = ops['patterns'] as List<dynamic>;
      final matches = [
        for (final p in patterns) (p as Map)['match'] as String,
      ];
      final eqEqIdx = matches.indexWhere((m) => m.contains('=='));
      final bareEqIdx = matches.indexWhere((m) => m == '=');
      expect(eqEqIdx, greaterThanOrEqualTo(0));
      expect(bareEqIdx, greaterThanOrEqualTo(0));
      expect(eqEqIdx, lessThan(bareEqIdx),
          reason: '`==` rule must precede bare `=` rule');
      final shiftIdx = matches.indexWhere((m) => m.startsWith('<<='));
      final compareIdx = matches.indexWhere((m) => m.contains('!='));
      expect(shiftIdx, greaterThanOrEqualTo(0));
      expect(compareIdx, greaterThanOrEqualTo(0));
      expect(shiftIdx, lessThan(compareIdx),
          reason: '`<<` rule must precede `<` comparison rule');
    });
  });
}
