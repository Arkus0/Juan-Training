import 'dart:io';

Future<void> main() async {
  final dir = Directory('assets/img/ejercicios');
  if (!await dir.exists()) {
    print('MISSING_DIR');
    return;
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .toList(growable: false);
  if (files.isEmpty) {
    print('NO_FILES');
    return;
  }
  final take = files.length < 5 ? files.length : 5;
  for (var i = 0; i < take; i++) {
    final f = files[i];
    final raf = f.openSync(mode: FileMode.read);
    final bytes = raf.readSync(8);
    raf.closeSync();
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print('${f.path} => $hex');
  }
}
