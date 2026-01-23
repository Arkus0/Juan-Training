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

Future<String?> _fetchNameViaTranslations(int id) async {
  const preferredLang = 4; // Spanish
  const fallbackLang = 2; // English
  try {
    final infoUrl = 'https://wger.de/api/v2/exerciseinfo/$id/';
    final infoResp = await http.get(Uri.parse(infoUrl)).timeout(const Duration(seconds: 8));
    if (infoResp.statusCode != 200) return null;
    final infoJson = jsonDecode(infoResp.body) as Map<String, dynamic>;
    final direct = (infoJson['name'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final translations = (infoJson['translations'] as List<dynamic>?) ?? [];
    String? candidate;
    int? transId;
    for (final t in translations) {
      if (t is Map<String, dynamic>) {
        final lang = t['language'];
        final tname = (t['name'] as String?)?.trim();
        if (lang == preferredLang && tname != null && tname.isNotEmpty) return tname;
        if (lang == fallbackLang && tname != null && tname.isNotEmpty) {
          candidate ??= tname;
        }
        if (lang == fallbackLang && transId == null) {
          final tid = t['id'];
          if (tid is int) transId = tid;
        }
      }
    }

    if (candidate != null) return candidate;

    if (transId != null) {
      final exUrl = 'https://wger.de/api/v2/exercise/$transId/';
      final exResp = await http.get(Uri.parse(exUrl)).timeout(const Duration(seconds: 8));
      if (exResp.statusCode == 200 && exResp.body.isNotEmpty) {
        final exJson = jsonDecode(exResp.body) as Map<String, dynamic>;
        final exName = (exJson['name'] as String?)?.trim();
        if (exName != null && exName.isNotEmpty) return exName;
      }
    }

    // try /exercise/{id}/ as last resort
    final exResp2 = await http.get(Uri.parse('https://wger.de/api/v2/exercise/$id/')).timeout(const Duration(seconds: 8));
    if (exResp2.statusCode == 200 && exResp2.body.isNotEmpty) {
      final exJson2 = jsonDecode(exResp2.body) as Map<String, dynamic>;
      final exName2 = (exJson2['name'] as String?)?.trim();
      if (exName2 != null && exName2.isNotEmpty) return exName2;
    }
  } catch (e) {
    stderr.writeln('fetch error for $id: $e');
  }
  return null;
}

Future<void> main(List<String> args) async {
  final batchSize = args.isNotEmpty ? int.tryParse(args[0]) ?? 50 : 50;
  final jsonFile = File('assets/data/exercises.json');
  if (!await jsonFile.exists()) {
    stderr.writeln('assets/data/exercises.json not found');
    return;
  }

  final list = (jsonDecode(await jsonFile.readAsString()) as List<dynamic>).cast<Map<String, dynamic>>();
  final missingIdx = <int>[];
  for (var i = 0; i < list.length; i++) {
    final entry = list[i];
    final name = entry['name'] as String?;
    if (_isPlaceholder(name)) missingIdx.add(i);
  }

  print('Total placeholders: ${missingIdx.length}');
  var processed = 0;
  var totalUpdated = 0;

  while (processed < missingIdx.length) {
    final end = (processed + batchSize) < missingIdx.length ? (processed + batchSize) : missingIdx.length;
    final slice = missingIdx.sublist(processed, end);
    var updatedThisBatch = 0;

    print('\nProcessing batch ${processed + 1}..$end (size ${slice.length})');
    for (final idx in slice) {
      final entry = list[idx];
      final id = entry['id'] as int;
      final found = await _fetchNameViaTranslations(id);
      if (found != null && found.isNotEmpty) {
        entry['name'] = found;
        updatedThisBatch++;
        totalUpdated++;
        print('Updated $id -> $found');
      } else {
        print('No name for $id');
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (updatedThisBatch > 0) {
      await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
      print('Wrote JSON; updated $updatedThisBatch names in this batch');
    } else {
      print('No updates in this batch');
    }

    processed = end;
  }

  print('\nDone. Total updated: $totalUpdated');
}
