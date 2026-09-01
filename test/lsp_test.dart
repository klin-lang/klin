@Tags(['unit'])
library;

import 'package:klin/analyze.dart';
import 'package:klin/complete.dart';
import 'package:klin/lsp/documents.dart';
import 'package:klin/lsp/semantic_tokens.dart';
import 'package:klin/lsp/server.dart';
import 'package:klin/token.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:test/test.dart';

void main() {
  group('LSP helpers', () {
    test('diagnosticRange maps 1-based SourcePos to 0-based LSP', () {
      final range = diagnosticRange(const SourcePos(2, 5));
      expect(range.start.line, 1);
      expect(range.start.character, 4);
      expect(range.end.line, 1);
      expect(range.end.character, 5);
    });

    test('formatDocumentEdits returns a full-document replace', () {
      const ugly = 'fn foo():void{let x:i32=1}';
      final edits = formatDocumentEdits(ugly);
      expect(edits, hasLength(1));
      expect(edits.single.newText, contains('fn foo'));
      expect(edits.single.range.start.line, 0);
      expect(edits.single.range.start.character, 0);
    });

    test('formatDocumentEdits returns empty on parse error', () {
      expect(formatDocumentEdits('fn {'), isEmpty);
    });

    test('uriToPath unwraps file URIs', () {
      final path = uriToPath(Uri.file('/tmp/hello.kl'));
      expect(path, contains('hello.kl'));
    });

    test('applyContentChange applies incremental range edits', () {
      const current = 'fn foo(): void {\n}\n';
      final change = Either2<TextDocumentContentChangeEvent1,
          TextDocumentContentChangeEvent2>.t1(
        TextDocumentContentChangeEvent1(
          range: Range(
            start: Position(line: 0, character: 3),
            end: Position(line: 0, character: 6),
          ),
          text: 'bar',
        ),
      );
      final next = applyContentChange(current, change);
      expect(next, 'fn bar(): void {\n}\n');
    });

    test('applyContentChange replaces whole document on full sync', () {
      const current = 'old';
      final change = Either2<TextDocumentContentChangeEvent1,
          TextDocumentContentChangeEvent2>.t2(
        TextDocumentContentChangeEvent2(text: 'fn main(): void {}\n'),
      );
      expect(applyContentChange(current, change), 'fn main(): void {}\n');
    });

    test('applyContentChange keeps buffer on corrupt incremental range', () {
      const current = 'fn foo(): void {}\n';
      final change = Either2<TextDocumentContentChangeEvent1,
          TextDocumentContentChangeEvent2>.t1(
        TextDocumentContentChangeEvent1(
          // Inverted range → end < start after offset mapping.
          range: Range(
            start: Position(line: 0, character: 10),
            end: Position(line: 0, character: 3),
          ),
          text: 'WIPED',
        ),
      );
      expect(applyContentChange(current, change), current);
    });

    test('toLspDiagnostics uses attributed open-document paths', () {
      final d = diagnosticForOpenDocument(
        const KlinDiagnostic(
          message: 'x',
          pos: SourcePos(2, 1),
          path: 'other.kl',
        ),
        'open.kl',
      );
      final lsp = toLspDiagnostics([d]).single;
      expect(lsp.range.start.line, 0);
      expect(lsp.message, contains('other.kl'));
    });

    test('toLspCompletionKind maps Klin kinds', () {
      expect(
        toLspCompletionKind(KlinCompletionKind.keyword),
        CompletionItemKind.Keyword,
      );
      expect(
        toLspCompletionKind(KlinCompletionKind.field),
        CompletionItemKind.Field,
      );
      expect(
        toLspCompletionKind(KlinCompletionKind.function),
        CompletionItemKind.Function,
      );
    });
  });

  group('semantic tokens (issue 094)', () {
    test('full tokens mark function / param / let / call / struct', () {
      const src = '''\
struct Point {
    x: i32
}
fn add(a: i32, b: i32): i32 {
    return a + b
}
fn main(): void {
    let mut n: i32 = add(1, 2)
}
''';
      final result = analyzeSource(path: 't.kl', source: src);
      expect(result.diagnostics, isEmpty);
      final tokens = buildSemanticTokens(result, openPath: 't.kl');
      final abs = _decodeSemanticTokens(tokens.data);
      expect(abs, isNotEmpty);

      bool has(int line, int col, int length, int type, {int? mods}) {
        return abs.any(
          (t) =>
              t.line == line &&
              t.col == col &&
              t.length == length &&
              t.type == type &&
              (mods == null || t.mods == mods),
        );
      }

      // Legend: function=0 method=1 parameter=2 variable=3 property=4 struct=5
      // declaration=1<<0, readonly=1<<1
      expect(has(1, 8, 5, 5, mods: 1), isTrue, reason: 'struct Point');
      expect(has(2, 5, 1, 4, mods: 1), isTrue, reason: 'field x');
      expect(has(4, 4, 3, 0, mods: 1), isTrue, reason: 'fn add');
      expect(has(4, 8, 1, 2, mods: 1), isTrue, reason: 'param a');
      expect(has(8, 13, 1, 3), isTrue, reason: 'let mut n (not readonly)');
      expect(has(8, 22, 3, 0), isTrue, reason: 'call add');
    });

    test('empty when no program', () {
      final empty = buildSemanticTokens(
        const AnalysisResult(diagnostics: [], program: null),
        openPath: 't.kl',
      );
      expect(empty.data, isEmpty);
    });

    test('legend matches advertised types', () {
      expect(klinSemanticTokensLegend.tokenTypes.first, 'function');
      expect(klinSemanticTokensLegend.tokenModifiers, contains('declaration'));
    });
  });

  group('DocumentStore', () {
    test('lastGood ignores analysis with parse errors (issue 092)', () {
      final docs = DocumentStore();
      const uri = 'file:///tmp/t.kl';
      const cleanSrc = '''
struct Point { x: i32 y: i32 }
fn main(): void {
}
''';
      final good = analyzeSource(
        path: 't.kl',
        source: cleanSrc,
        requireMain: false,
      );
      expect(good.hasParseErrors, isFalse);
      docs.setAnalysis(uri, good);
      expect(docs.lastGood(uri)?.program, isNotNull);

      final broken = analyzeSource(
        path: 't.kl',
        source: '''
struct Point { x: i32 y: i32 }
fn main(): void {
    let z: i32 = p.
}
''',
        requireMain: false,
      );
      expect(broken.hasParseErrors, isTrue);
      expect(broken.program, isNotNull);
      docs.setAnalysis(uri, broken);
      expect(
        identical(docs.lastGood(uri)?.program, good.program),
        isTrue,
        reason: 'partial parse must not replace lastGood',
      );
    });
  });
}

final class _AbsTok {
  final int line;
  final int col;
  final int length;
  final int type;
  final int mods;
  _AbsTok(this.line, this.col, this.length, this.type, this.mods);
}

/// Decode LSP relative semantic-token data to 1-based line/col.
List<_AbsTok> _decodeSemanticTokens(List<int> data) {
  final out = <_AbsTok>[];
  var line = 1;
  var col = 1;
  for (var i = 0; i + 4 < data.length; i += 5) {
    final dLine = data[i];
    final dCol = data[i + 1];
    line += dLine;
    col = dLine == 0 ? col + dCol : dCol + 1;
    out.add(_AbsTok(line, col, data[i + 2], data[i + 3], data[i + 4]));
  }
  return out;
}
