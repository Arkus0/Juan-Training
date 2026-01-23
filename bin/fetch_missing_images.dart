import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

Future<void> main(List<String> args) async {
  final jsonFile = File('assets/data/exercises.json');
  if (!await jsonFile.exists()) {
    stderr.writeln('exercises.json not found');
    exit(2);
  }
  final list = (jsonDecode(await jsonFile.readAsString()) as List).cast<Map<String, dynamic>>();
  var updated = 0;
  final missing = <int>[];

  for (final entry in list) {
    final id = entry['id'] as int;
    final local = (entry['localImagePath'] as String?) ?? '';
    if (local.isNotEmpty) {
      final f = File(local);
      if (await f.exists()) continue;
    }
    // try to fetch from API
    try {
      final infoUrl = 'https://wger.de/api/v2/exerciseinfo/$id/';
      final resp = await http.get(Uri.parse(infoUrl)).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        missing.add(id);
        continue;
      }
      final info = jsonDecode(resp.body) as Map<String, dynamic>;
      final images = (info['images'] as List<dynamic>?) ?? [];
      String? imgUrl;
      if (images.isNotEmpty) {
        final first = images.firstWhere((e) => e is Map<String, dynamic>, orElse: () => null) as Map<String, dynamic>?;
        imgUrl = first?['image'] as String?;
      }
      if (imgUrl == null || imgUrl.isEmpty) {
        missing.add(id);
        continue;
      }
      final imgResp = await http.get(Uri.parse(imgUrl)).timeout(const Duration(seconds: 15));
      if (imgResp.statusCode != 200) {
        missing.add(id);
        continue;
      }
      final decoded = img.decodeImage(imgResp.bodyBytes);
      if (decoded == null) {
        missing.add(id);
        continue;
      }
      final outDir = Directory('assets/img/ejercicios');
      if (!await outDir.exists()) await outDir.create(recursive: true);
      final outPath = 'assets/img/ejercicios/$id.png';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodePng(decoded));
      entry['localImagePath'] = outPath;
      updated++;
      print('Fetched image for $id');
      // small delay to be polite
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      stderr.writeln('error for $id: $e');
      missing.add(id);
    }
  }

  if (updated > 0) {
    await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
    print('Wrote JSON; updated $updated entries');
  }

  print('Done. Missing count: ${missing.length}');
}
