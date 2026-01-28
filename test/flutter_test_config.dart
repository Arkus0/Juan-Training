import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform(this._basePath);

  final String _basePath;

  @override
  Future<String?> getTemporaryPath() async => _basePath;

  @override
  Future<String?> getApplicationSupportPath() async => _basePath;

  @override
  Future<String?> getLibraryPath() async => _basePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _basePath;

  @override
  Future<String?> getApplicationCachePath() async => _basePath;

  @override
  Future<String?> getExternalStoragePath() async => _basePath;

  @override
  Future<List<String>?> getExternalCachePaths() async => [_basePath];

  @override
  Future<List<String>?> getExternalStoragePaths(
          {StorageDirectory? type,}) async =>
      [_basePath];

  @override
  Future<String?> getDownloadsPath() async => _basePath;
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final tempDir = Directory.systemTemp.createTempSync('juan_training_test_');
  PathProviderPlatform.instance = _TestPathProviderPlatform(tempDir.path);
  await initializeDateFormatting('es_ES');
  await testMain();
}
