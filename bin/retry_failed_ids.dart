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

Future<String?> _fetchWithRetries(int id, {int retries = 3, Duration timeout = const Duration(seconds: 15)}) async {
  for (var attempt = 1; attempt <= retries; attempt++) {
    try {
      final url = 'https://wger.de/api/v2/exerciseinfo/$id/';
      final resp = await http.get(Uri.parse(url)).timeout(timeout);
      if (resp.statusCode != 200) return null;
      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      final direct = (jsonMap['name'] as String?)?.trim();
      if (direct != null && direct.isNotEmpty) return direct;
      final translations = (jsonMap['translations'] as List<dynamic>?) ?? [];
      for (final t in translations) {
        if (t is Map<String, dynamic>) {
          final tname = (t['name'] as String?)?.trim();
          if (tname != null && tname.isNotEmpty) return tname;
          final tid = t['id'];
          if (tid is int) {
            final exUrl = 'https://wger.de/api/v2/exercise/$tid/';
            final exResp = await http.get(Uri.parse(exUrl)).timeout(timeout);
            if (exResp.statusCode == 200) {
              final exJson = jsonDecode(exResp.body) as Map<String, dynamic>;
              final exName = (exJson['name'] as String?)?.trim();
              if (exName != null && exName.isNotEmpty) return exName;
            }
          }
        }
      }

      // try /exercise/{id}/ as last resort
      final exResp2 = await http.get(Uri.parse('https://wger.de/api/v2/exercise/$id/')).timeout(timeout);
      if (exResp2.statusCode == 200) {
        final exJson2 = jsonDecode(exResp2.body) as Map<String, dynamic>;
        final exName2 = (exJson2['name'] as String?)?.trim();
        if (exName2 != null && exName2.isNotEmpty) return exName2;
      }

      return null;
    } catch (e) {
      stderr.writeln('Attempt $attempt failed for $id: $e');
      if (attempt < retries) await Future.delayed(Duration(seconds: 1 * attempt));
    }
  }
  return null;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run bin/retry_failed_ids.dart <id> [id2 id3 ...]');
    return;
  }

  final ids = args.map(int.tryParse).whereType<int>().toList();
  if (ids.isEmpty) {
    stderr.writeln('No valid IDs provided');
    return;
  }

  final jsonFile = File('assets/data/exercises.json');
  if (!await jsonFile.exists()) {
    stderr.writeln('assets/data/exercises.json not found');
    return;
  }

  final list = (jsonDecode(await jsonFile.readAsString()) as List<dynamic>).cast<Map<String, dynamic>>();
  var updated = 0;
  for (final id in ids) {
    final entry = list.firstWhere((e) => (e['id'] as int) == id, orElse: () => {} as Map<String, dynamic>);
    if (entry.isEmpty) {
      print('ID $id not found in JSON');
      continue;
    }
    final currentName = entry['name'] as String?;
    if (!_isPlaceholder(currentName)) {
      print('ID $id already has name: $currentName');
      continue;
    }

    print('Retrying $id...');
    final found = await _fetchWithRetries(id, retries: 4, timeout: Duration(seconds: 20));
    if (found != null && found.isNotEmpty) {
      entry['name'] = found;
      updated++;
      print('Updated $id -> $found');
      await jsonFile.writeAsString(JsonEncoder.withIndent('  ').convert(list));
    } else {
      print('Still no name for $id');
    }
    await Future.delayed(Duration(milliseconds: 200));
  }

  print('\nRetry run finished. Updated: $updated');
}
