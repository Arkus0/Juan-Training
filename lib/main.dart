import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/main_screen.dart';
import 'utils/design_system.dart';
import 'services/exercise_library_service.dart';
import 'services/alternativas_service.dart';
import 'services/timer_audio_service.dart';
import 'services/timer_notification_service.dart';
import 'services/haptics_controller.dart';
import 'services/media_control_service.dart';
import 'services/media_session_service.dart';
import 'services/app_lifecycle_manager.dart';
import 'providers/training_provider.dart';

import 'database/database.dart';
import 'repositories/drift_training_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración de caché de imágenes
  PaintingBinding.instance.imageCache.maximumSize = 300;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 * 1024 * 1024;

  // Drift
  final appDb = AppDatabase();
  final driftRepository = DriftTrainingRepository(appDb);

  // Load Library (Service uses local file now)
  await ExerciseLibraryService.instance.init();

  // Load Alternativas
  await AlternativasService.instance.initialize();

  // Initialize Timer Audio Service
  await TimerAudioService.instance.initialize();

  // Initialize Timer Notification Service (for lock screen timer)
  await TimerNotificationService.instance.initialize();

  // Initialize HapticsController globally for vibration to work everywhere
  // This registers the lifecycle observer so haptics work on buttons, timers, etc.
  HapticsController.instance.initialize();

  // Initialize MediaControlService for Spotify detection
  // This starts polling for active media sessions
  await MediaControlService.instance.initialize();

  // Initialize MediaSessionManagerService for media controls
  MediaSessionManagerService.instance.initialize();

  // 🎯 CRITICAL: Initialize AppLifecycleManager LAST
  // This manages cleanup of all services when app closes
  AppLifecycleManager.instance.initialize();

  await initializeDateFormatting('es_ES', null);

  runApp(ProviderScope(
    overrides: [
       trainingRepositoryProvider.overrideWithValue(driftRepository),
    ],
    child: const JuanTrainingApp(),
  ));
}

class JuanTrainingApp extends StatelessWidget {
  const JuanTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juan Training',
      debugShowCheckedModeBanner: false,
      // 🎯 NUEVO: Usar sistema de diseño rediseñado
      theme: buildAppTheme(),
      home: const MainScreen(),
    );
  }
}
