import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Simple script to fetch exercises from Wger API, download the first image
/// for each exercise and write a bundled JSON to `assets/data/exercises.json`.
///
/// Run from repo root: `dart run bin/generate_exercises.dart`

Future<void> main() async {
  final imagesDir = Directory('assets/img/ejercicios');
  if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

  final List<int> languages = [4, 2]; // Spanish then English

  // Use a map to merge entries by id, preferring Spanish values when available
  final Map<int, Map<String, dynamic>> byId = {};

  for (final lang in languages) {
    String? url = 'https://wger.de/api/v2/exerciseinfo/?language=$lang&limit=100';
    while (url != null && url.isNotEmpty) {
      print('Fetching $url');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        stderr.writeln('Failed to fetch $url: ${resp.statusCode}');
        break;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>?) ?? [];
      for (final item in results) {
        if (item is! Map) continue;
        final id = item['id'] as int;
        final nameRaw = (item['name'] ?? '').toString().trim();
        final descriptionRaw = item['description']?.toString().trim() ?? '';

        final imageUrls = <String>[];
        if (item['images'] is List) {
          for (final im in item['images']) {
            final u = (im['image'] as String?)?.trim();
            if (u != null && u.isNotEmpty) imageUrls.add(u);
          }
        }

        final existing = byId[id];
        if (existing == null) {
          byId[id] = {
            'id': id,
            'name': nameRaw,
            'muscleGroup': item['category'] is Map
                ? item['category']['name']
                : (item['category']?.toString() ?? 'Otro'),
            'equipment': (item['equipment'] is List &&
                    (item['equipment'] as List).isNotEmpty)
                ? ((item['equipment'][0] is Map)
                    ? item['equipment'][0]['name']
                    : item['equipment'][0].toString())
                : 'Otro',
            'description': descriptionRaw,
            'license': item['license_author'] as String?,
            'imageUrls': imageUrls,
            'localImagePath': null,
            'muscles': item['muscles'] is List ? item['muscles'] : [],
            'secondaryMuscles':
                item['muscles_secondary'] is List ? item['muscles_secondary'] : [],
          };
        } else {
          if (((existing['name'] as String?)?.trim() ?? '').isEmpty &&
              nameRaw.isNotEmpty) {
            existing['name'] = nameRaw;
          }
          if ((existing['description'] as String?)?.trim().isEmpty ?? true) {
            existing['description'] = descriptionRaw;
          }
          final existingUrls =
              (existing['imageUrls'] as List<dynamic>).cast<String>();
          for (final u in imageUrls) {
            if (!existingUrls.contains(u)) existingUrls.add(u);
          }
          existing['imageUrls'] = existingUrls;
        }
      }

      url = (data['next'] as String?);
    }
  }

  // Download and re-encode first image for each entry
  for (final entry in byId.values) {
    final id = entry['id'] as int;
    final images = (entry['imageUrls'] as List<dynamic>).cast<String>();
    if (images.isEmpty) continue;
    final imgUrl = images.first;
    try {
      final uri = Uri.parse(imgUrl);
      final outPath = '${imagesDir.path}/$id.png';
      final outFile = File(outPath);
      if (!await outFile.exists()) {
        final r = await http.get(uri).timeout(const Duration(seconds: 20));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          final decoded = img.decodeImage(r.bodyBytes);
          if (decoded != null) {
            final encoded = img.encodePng(decoded);
            await outFile.writeAsBytes(encoded);
            entry['localImagePath'] = outPath.replaceAll('\\', '/');
            print('Downloaded & re-encoded image for $id -> $outPath');
          } else {
            stderr.writeln('Could not decode image for $id from $imgUrl');
          }
        }
      } else {
        entry['localImagePath'] = outPath.replaceAll('\\', '/');
      }
    } catch (e) {
      stderr.writeln('Image download failed for $id: $e');
    }
  }

  final outJson = byId.values.toList();
  final outFile = File('assets/data/exercises.json');
  if (!await outFile.parent.exists()) {
    await outFile.parent.create(recursive: true);
  }
  await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(outJson));
  print('Wrote ${outJson.length} exercises to ${outFile.path}');
}