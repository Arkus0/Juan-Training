import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/main_provider.dart';
import 'rutinas_screen.dart';
import 'train_selection_screen.dart';
import 'history_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static final List<Widget> _pages = const [
    RutinasScreen(),
    TrainSelectionScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
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
          ],
        ),
      ),
    );
  }
}
