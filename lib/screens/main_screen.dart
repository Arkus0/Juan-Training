import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/main_provider.dart';
import '../widgets/session/active_session_bar.dart';
import 'rutinas_screen.dart';
import 'train_selection_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const List<Widget> _pages = [
    RutinasScreen(),
    TrainSelectionScreen(),
    HistoryScreen(),
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
              icon: Icon(Icons.history),
              label: 'HISTORIAL',
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
