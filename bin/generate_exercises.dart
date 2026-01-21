import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Simple script to fetch exercises from Wger API, download the first image
/// for each exercise and write a bundled JSON to `assets/data/exercises.json`.
///
/// Run from repo root: `dart run bin/generate_exercises.dart`

Future<void> main() async {
  final outJson = <Map<String, dynamic>>[];
  final imagesDir = Directory('assets/img/ejercicios');
  if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

  final List<int> languages = [4, 2]; // Spanish then English

  final seenIds = <int>{};

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
        if (seenIds.contains(id)) continue;
        seenIds.add(id);

        final name = (item['name'] ?? '').toString();
        final description = item['description']?.toString();

        // Images
        final List<String> imageUrls = [];
        if (item['images'] is List) {
          for (final img in item['images']) {
            final url = img['image'] as String?;
            if (url != null) imageUrls.add(url);
          }
        }

        String? localImagePath;
        if (imageUrls.isNotEmpty) {
          final imgUrl = imageUrls.first;
          try {
            final uri = Uri.parse(imgUrl);
            final ext = uri.path.endsWith('.png') ? 'png' : 'jpg';
            final filePath = '${imagesDir.path}/$id.$ext';
            final file = File(filePath);
            if (!await file.exists()) {
              final r = await http.get(uri).timeout(const Duration(seconds: 20));
              if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
                await file.writeAsBytes(r.bodyBytes);
                localImagePath = filePath.replaceAll('\\', '/');
                print('Downloaded image for $id -> $filePath');
              }
            } else {
              localImagePath = filePath.replaceAll('\\', '/');
            }
          } catch (e) {
            stderr.writeln('Image download failed for $id: $e');
          }
        }

        final Map<String, dynamic> entry = {
          'id': id,
          'name': name,
          'muscleGroup': item['category'] is Map ? item['category']['name'] : (item['category']?.toString() ?? 'Otro'),
          'equipment': (item['equipment'] is List && (item['equipment'] as List).isNotEmpty)
              ? ((item['equipment'][0] is Map) ? item['equipment'][0]['name'] : item['equipment'][0].toString())
              : 'Otro',
          'description': description,
          'license': item['license_author'] as String?,
          'imageUrls': imageUrls,
          'localImagePath': localImagePath,
          'muscles': [],
          'secondaryMuscles': [],
        };

        outJson.add(entry);
      }

      final next = data['next'] as String?;
      if (next == null) break;
      url = next;
    }
  }

  final outFile = File('assets/data/exercises.json');
  if (!await outFile.parent.exists()) await outFile.parent.create(recursive: true);
  await outFile.writeAsString(JsonEncoder.withIndent('  ').convert(outJson));
  print('Wrote ${outJson.length} exercises to ${outFile.path}');
}
