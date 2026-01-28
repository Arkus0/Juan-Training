import 'dart:convert';
import 'dart:io';

final providerPatterns = [
  RegExp(r"\b(StateNotifierProvider|StateProvider|StreamProvider|FutureProvider|Provider<|ChangeNotifierProvider|NotifierProvider)\b"),
  RegExp(r"\bautoDispose\b"),
];

void main(List<String> args) {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('No se encontró la carpeta `lib`. Ejecuta desde la raíz del proyecto.');
    exit(1);
  }

  final results = <String, List<String>>{};

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();
      final matches = <String>{};
      for (final pat in providerPatterns) {
        for (final m in pat.allMatches(content)) {
          final line = _lineForOffset(content, m.start);
          matches.add(line.trim());
        }
      }
      if (matches.isNotEmpty) {
        results[entity.path] = matches.toList();
      }
    }
  }

  printJson(results);
}

String _lineForOffset(String content, int offset) {
  final start = content.lastIndexOf('\n', offset - 1);
  final end = content.indexOf('\n', offset);
  final s = start == -1 ? 0 : start + 1;
  final e = end == -1 ? content.length : end;
  return content.substring(s, e);
}

void printJson(Map<String, List<String>> results) {
  final encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(results));
}
