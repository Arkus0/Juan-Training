import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/main_provider.dart';
import '../utils/design_system.dart';
import '../widgets/session/active_session_bar.dart';
import 'analysis_screen.dart';
import 'rutinas_screen.dart';
import 'settings_screen.dart';
import 'train_selection_screen.dart';

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
      // NO mostrar si:
      // 1. Ya hay sesión activa (ActiveSessionBar la maneja)
      // 2. Estamos en tab RUTINAS (tiene su propio FAB)
      floatingActionButton: null,
      floatingActionButtonLocation: null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              // 🎯 REDISEÑO: Borde sutil
              color: AppColors.border,
              width: 1,
            ),
          ),
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
}
