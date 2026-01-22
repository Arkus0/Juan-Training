import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/main_provider.dart';
import '../providers/training_provider.dart';
import '../widgets/session/active_session_bar.dart';
import 'rutinas_screen.dart';
import 'train_selection_screen.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';
import 'training_session_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const List<Widget> _pages = [
    RutinasScreen(),
    TrainSelectionScreen(),
    AnalysisScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    
    // 🎯 UX MEDIO: FAB con sugerencia inteligente
    final suggestionAsync = ref.watch(smartSuggestionProvider);
    final activeSession = ref.watch(trainingSessionProvider);
    final hasActiveSession = activeSession.startTime != null;

      // Floating timer removed — devolvemos el Scaffold directamente
    return Scaffold(
      // Usamos Column para poder insertar la ActiveSessionBar en la parte inferior
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: _pages,
            ),
          ),

          // Barra que aparece solo cuando hay una sesión activa
          const ActiveSessionBar(),
        ],
      ),
      // 🎯 UX MEDIO: FAB flotante para acceso rápido a entrenar
      floatingActionButton: hasActiveSession 
          ? null  // No mostrar FAB si ya hay sesión activa (ActiveSessionBar la maneja)
          : suggestionAsync.when(
              data: (suggestion) {
                if (suggestion == null) return null;
                return FloatingActionButton.extended(
                  heroTag: 'quick_start_fab',
                  onPressed: () => _startSuggestedSession(context, ref, suggestion),
                  backgroundColor: Colors.red[900],
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: Text(
                    suggestion.dayName.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                );
              },
              loading: () => null,
              error: (_, __) => null,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            ref.read(bottomNavIndexProvider.notifier).state = index;
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'RUTINAS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'ENTRENAR',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights),
              label: 'ANÁLISIS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'AJUSTES',
            ),
          ],
        ),
      ),
    );
  }
  
  /// Inicia la sesión sugerida directamente desde el FAB
  void _startSuggestedSession(BuildContext context, WidgetRef ref, SmartWorkoutSuggestion suggestion) {
    final rutina = suggestion.rutina;
    final dayIndex = suggestion.dayIndex;
    
    if (rutina.dias.isEmpty || dayIndex >= rutina.dias.length) return;
    
    final day = rutina.dias[dayIndex];
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    
    ref.read(trainingSessionProvider.notifier).startSession(
      rutina,
      day.ejercicios,
      dayName: day.nombre,
      dayIndex: dayIndex,
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrainingSessionScreen()),
    );
  }
}
