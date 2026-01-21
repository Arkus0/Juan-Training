import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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
    String url = 'https://wger.de/api/v2/exerciseinfo/?language=$lang&limit=100';
    while (url.isNotEmpty) {
      print('Fetching $url');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        stderr.writeln('Failed to fetch $url: ${resp.statusCode}');
        break;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>;
      for (final item in results) {
        final id = item['id'] as int;
        final nameRaw = (item['name'] ?? '').toString().trim();
        final descriptionRaw = item['description']?.toString();

        // Images
        final List<String> imageUrls = [];
        if (item['images'] is List) {
          for (final img in item['images']) {
            final urlImg = img['image'] as String?;
            if (urlImg != null) imageUrls.add(urlImg);
          }
        }

        // Prepare or merge entry
        final existing = byId[id];
        if (existing == null) {
          byId[id] = {
            'id': id,
            'name': nameRaw,
            'muscleGroup': item['category'] is Map ? item['category']['name'] : (item['category']?.toString() ?? 'Otro'),
            'equipment': (item['equipment'] is List && (item['equipment'] as List).isNotEmpty)
                ? ((item['equipment'][0] is Map) ? item['equipment'][0]['name'] : item['equipment'][0].toString())
                : 'Otro',
            'description': descriptionRaw,
            'license': item['license_author'] as String?,
            'imageUrls': imageUrls,
            'localImagePath': null,
            'muscles': [],
            'secondaryMuscles': [],
          };
        } else {
          // Merge: prefer non-empty name/description if existing is empty and current has value
          if (((existing['name'] as String?)?.trim() ?? '').isEmpty && nameRaw.isNotEmpty) {
            existing['name'] = nameRaw;
          }
          if ((existing['description'] as String?)?.trim().isEmpty ?? true) {
            existing['description'] = descriptionRaw;
          }
          // Merge imageUrls (keep unique)
          final List<String> existingUrls = (existing['imageUrls'] as List<dynamic>).cast<String>();
          for (final u in imageUrls) {
            if (!existingUrls.contains(u)) existingUrls.add(u);
          }
          existing['imageUrls'] = existingUrls;
        }
      }

      final next = data['next'] as String?;
      if (next == null) break;
      url = next;
    }
  }

  // After gathering entries, download first available image per entry
  for (final entry in byId.values) {
    final id = entry['id'] as int;
    final images = (entry['imageUrls'] as List<dynamic>).cast<String>();
    if (images.isNotEmpty) {
      final imgUrl = images.first;
      try {
        final uri = Uri.parse(imgUrl);
        final ext = uri.path.endsWith('.png') ? 'png' : 'jpg';
        final filePath = '${imagesDir.path}/$id.$ext';
        final file = File(filePath);
        if (!await file.exists()) {
          final r = await http.get(uri).timeout(const Duration(seconds: 20));
          if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
            await file.writeAsBytes(r.bodyBytes);
            entry['localImagePath'] = filePath.replaceAll('\\', '/');
            print('Downloaded image for $id -> $filePath');
          }
        } else {
          entry['localImagePath'] = filePath.replaceAll('\\', '/');
        }
      } catch (e) {
        stderr.writeln('Image download failed for $id: $e');
      }
    }
  }

  final outJson = byId.values.toList();
  final outFile = File('assets/data/exercises.json');
  if (!await outFile.parent.exists()) await outFile.parent.create(recursive: true);
  await outFile.writeAsString(JsonEncoder.withIndent('  ').convert(outJson));
  print('Wrote ${outJson.length} exercises to ${outFile.path}');
}
