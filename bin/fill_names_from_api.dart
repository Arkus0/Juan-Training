import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

bool _isPlaceholder(String? name, int id) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return true;
  final re = RegExp(r'^Ejercicio\s*\d+$', caseSensitive: false);
  if (re.hasMatch(n)) return true;
  // also consider generic 'Exercise' placeholders
  if (n.toLowerCase().startsWith('exercise')) return true;
  return false;
}

Future<void> main() async {
  final jsonFile = File('assets/data/exercises.json');
  if (!await jsonFile.exists()) {
    stderr.writeln('assets/data/exercises.json not found');
    return;
  }

  final text = await jsonFile.readAsString();
  final list = (jsonDecode(text) as List<dynamic>).cast<Map<String, dynamic>>();

  final missing = <Map<String, dynamic>>[];
  for (final entry in list) {
    final id = entry['id'] as int;
    final name = entry['name'] as String?;
    if (_isPlaceholder(name, id)) missing.add(entry);
  }

  stdout
      .writeln('Found ${missing.length} placeholder names to attempt filling');
  final langs = [4, 2]; // Spanish, then English
  var updated = 0;

  for (final entry in missing) {
    final id = entry['id'] as int;
    String? foundName;
    for (final lang in langs) {
      try {
        final url = 'https://wger.de/api/v2/exerciseinfo/$id/?language=$lang';
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200 && resp.body.isNotEmpty) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final n = (data['name'] as String?)?.trim();
          if (n != null && n.isNotEmpty) {
            foundName = n;
            break;
          }
        }
      } catch (e) {
        stderr.writeln('Error fetching $id lang=$lang: $e');
      }
      // polite pause
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (foundName != null) {
      entry['name'] = foundName;
      updated++;
      stdout.writeln('Updated name for $id -> $foundName');
    }
  }

  if (updated > 0) {
    await jsonFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(list));
    stdout.writeln('Wrote updated JSON, updated $updated names');
  } else {
    stdout.writeln('No names updated');
  }
}
