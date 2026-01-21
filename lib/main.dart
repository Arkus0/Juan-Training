import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_screen.dart';
import 'services/exercise_library_service.dart';
import 'providers/training_provider.dart';

import 'database/database.dart';
import 'repositories/drift_training_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Drift
  final appDb = AppDatabase();
  final driftRepository = DriftTrainingRepository(appDb);

  // Load Library (Service uses local file now)
  await ExerciseLibraryService.instance.init();

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
    // Define Colors
    final primaryRed = Colors.red[900]!; // #B71C1C
    final accentRed = Colors.redAccent[700]!; // #FF1744
    const bgBlack = Colors.black;
    final bgGrey = Colors.grey[900]!;

    return MaterialApp(
      title: 'Juan Training',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgBlack,
        primaryColor: primaryRed,
        colorScheme: ColorScheme.dark(
          primary: primaryRed,
          secondary: accentRed,
          surface: bgGrey,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          error: accentRed,
        ),

        // Typography
        textTheme: TextTheme(
          headlineLarge: GoogleFonts.montserrat(
            fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
          headlineMedium: GoogleFonts.montserrat(
            fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
          headlineSmall: GoogleFonts.montserrat(
            fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),

          titleLarge: GoogleFonts.montserrat(
            fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
          titleMedium: GoogleFonts.montserrat(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          titleSmall: GoogleFonts.montserrat(
            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9)),

          bodyLarge: GoogleFonts.montserrat(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          bodyMedium: GoogleFonts.montserrat(
            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8)),
          bodySmall: GoogleFonts.montserrat(
            fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6)),

          labelLarge: GoogleFonts.montserrat( // Button text
            fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),

        // AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: primaryRed,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: GoogleFonts.montserrat(
            fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
        ),

        // Cards
        cardTheme: CardThemeData(
          color: bgGrey,
          elevation: 2,
          shadowColor: bgGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        ),

        // Bottom Navigation
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: bgBlack,
          selectedItemColor: accentRed,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
          elevation: 10, // Simulated "iron bar" feel
          type: BottomNavigationBarType.fixed,
        ),

        // Inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgGrey,
          labelStyle: GoogleFonts.montserrat(color: Colors.white70, fontWeight: FontWeight.w700),
          hintStyle: GoogleFonts.montserrat(color: Colors.white38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: accentRed, width: 2),
          ),
        ),

        // Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed,
            foregroundColor: Colors.white,
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),

        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: accentRed,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: const CircleBorder(),
        ),

        // Checkbox/Switch
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentRed;
            return Colors.transparent;
          }),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 2),
          checkColor: WidgetStateProperty.all(Colors.white),
          shape: const CircleBorder(),
        ),

        dividerColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      home: const MainScreen(),
    );
  }
}
