import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

Future<void> main() async {
  final imagesDir = Directory('assets/img/ejercicios');
  if (!await imagesDir.exists()) {
    stderr.writeln('Images dir missing');
    return;
  }
  final jsonFile = File('assets/data/exercises.json');
  if (!await jsonFile.exists()) {
    stderr.writeln('JSON missing');
    return;
  }

  final jsonText = await jsonFile.readAsString();
  final data = jsonDecode(jsonText) as List<dynamic>;
  final Map<int, Map<String, dynamic>> byId = {
    for (final e in data)
      (e['id'] as int): Map<String, dynamic>.from(e as Map<String, dynamic>)
  };

  final files = imagesDir
      .listSync()
      .whereType<File>()
      .toList(growable: false);

  for (final f in files) {
    try {
      final bytes = await f.readAsBytes();
      if (bytes.length < 8) continue;
      final isPng = bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e;
      final isJpeg = bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
      final name = f.uri.pathSegments.last;
      final idPart = name.split('.').first;
      final id = int.tryParse(idPart);
      if (id == null) continue;
      final outPath = '${imagesDir.path}\$id.png';
      final outFile = File(outPath);

      if (isPng) {
        // ensure correct .png name
        if (!f.path.endsWith('.png')) {
          await f.copy(outPath);
          await f.delete();
        }
        // set localImagePath
        final entry = byId[id];
        if (entry != null) entry['localImagePath'] = outPath.replaceAll('\\', '/');
        continue;
      }

      if (isJpeg || !isPng) {
        // decode and write PNG
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          stderr.writeln('Could not decode ${f.path}');
          continue;
        }
        final encoded = img.encodePng(decoded);
        await outFile.writeAsBytes(encoded);
        // remove original if different
        if (f.path != outFile.path) await f.delete();
        final entry = byId[id];
        if (entry != null) entry['localImagePath'] = outFile.path.replaceAll('\\', '/');
        print('Normalized $id -> ${outFile.path}');
      }
    } catch (e) {
      stderr.writeln('Error processing ${f.path}: $e');
    }
  }

  // Fill empty names and write back JSON
  final outList = <Map<String, dynamic>>[];
  for (final id in byId.keys) {
    final m = byId[id]!;
    final name = (m['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      m['name'] = 'Ejercicio $id';
    }
    // ensure localImagePath exists else null
    final lip = m['localImagePath'] as String?;
    if (lip != null) {
      if (!File(lip).existsSync()) m['localImagePath'] = null;
    }
    outList.add(m);
  }

  outList.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
  await jsonFile.writeAsString(JsonEncoder.withIndent('  ').convert(outList));
  print('Updated JSON with ${outList.length} entries');
}
