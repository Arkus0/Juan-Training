import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

bool _isPlaceholder(String? name) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return true;
  final re = RegExp(r'^Ejercicio\s*\d+$', caseSensitive: false);
  if (re.hasMatch(n)) return true;
  if (n.toLowerCase().startsWith('exercise')) return true;
  return false;
}

Future<void> main(List<String> args) async {
  final start = args.isNotEmpty ? int.tryParse(args[0]) ?? 0 : 0;
  final batch = args.length > 1 ? int.tryParse(args[1]) ?? 50 : 50;
  stdout.writeln('Batch start=$start size=$batch');

  final jsonFile = File('assets/data/exercises.json');
  if (!await jsonFile.exists()) {
    stderr.writeln('assets/data/exercises.json not found');
    return;
  }

  final list = (jsonDecode(await jsonFile.readAsString()) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final missingIdx = <int>[];
  for (var i = 0; i < list.length; i++) {
    final entry = list[i];
    final name = entry['name'] as String?;
    if (_isPlaceholder(name)) missingIdx.add(i);
  }

  stdout.writeln('Total placeholders: ${missingIdx.length}');
  if (start >= missingIdx.length) {
    stdout.writeln('Start >= total placeholders, nothing to do');
    return;
  }

  final end =
      (start + batch) < missingIdx.length ? (start + batch) : missingIdx.length;
  final slice = missingIdx.sublist(start, end);

  final langs = [4, 2];
  var updated = 0;

  for (final idx in slice) {
    final entry = list[idx];
    final id = entry['id'] as int;
    String? foundName;
    for (final lang in langs) {
      try {
        final url = 'https://wger.de/api/v2/exerciseinfo/$id/?language=$lang';
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
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
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (foundName != null) {
      entry['name'] = foundName;
      updated++;
      stdout.writeln('Updated $id -> $foundName');
    } else {
      stdout.writeln('No name for $id');
    }
  }

  if (updated > 0) {
    await jsonFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(list));
    stdout.writeln('Wrote JSON; updated $updated names in this batch');
  } else {
    stdout.writeln('No updates in this batch');
  }

  stdout.writeln(
      'Batch done: processed ${slice.length} placeholders (indexes $start..${end - 1})',);
}
