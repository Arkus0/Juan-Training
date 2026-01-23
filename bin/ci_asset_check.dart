import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

bool _isPlaceholder(String? name) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return true;
  final re = RegExp(r'^Ejercicio\s*\d+$', caseSensitive: false);
  if (re.hasMatch(n)) return true;
  if (n.toLowerCase().startsWith('exercise')) return true;
  return false;
}

Future<void> main(List<String> args) async {
  final jsonFile = File('assets/data/exercises.json');
  final reportFile = File('ci_report_assets.json');
  final report = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'placeholder_names': <int>[],
    'missing_images': <int>[],
    'invalid_images': <int>[],
    'entries_checked': 0
  };

  if (!await jsonFile.exists()) {
    stderr.writeln('ERROR: assets/data/exercises.json not found');
    exit(2);
  }

  final content = await jsonFile.readAsString();
  final list = (jsonDecode(content) as List<dynamic>).cast<Map<String, dynamic>>();
  report['entries_checked'] = list.length;

  for (final entry in list) {
    final id = entry['id'] as int?;
    if (id == null) continue;
    final name = entry['name'] as String?;
    if (_isPlaceholder(name)) report['placeholder_names'].add(id);

    final path = (entry['localImagePath'] as String?) ?? '';
    if (path.isEmpty) {
      report['missing_images'].add(id);
      continue;
    }

    final f = File(path);
    if (!await f.exists()) {
      report['missing_images'].add(id);
      continue;
    }

    try {
      final bytes = await f.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        report['invalid_images'].add(id);
      }
    } catch (e) {
      report['invalid_images'].add(id);
    }
  }

  await reportFile.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  print('Asset check finished. Report written to ${reportFile.path}');
  print('Placeholders: ${report['placeholder_names'].length}');
  print('Missing images: ${report['missing_images'].length}');
  print('Invalid images: ${report['invalid_images'].length}');

  // exit code 0 even on warnings; caller script may parse report
}
