import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/exercise_library_service.dart';
import 'rutinas_screen.dart';
import 'history_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLibrarySync();
    });
  }

  Future<void> _checkLibrarySync() async {
    final service = ExerciseLibraryService.instance;
    if (await service.shouldSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Actualizando biblioteca de ejercicios...'),
          duration: Duration(days: 1), // Stay visible until dismissed
        ),
      );

      final success = await service.syncLibrary();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biblioteca actualizada.')),
        );
      } else {
        // If sync failed, check if we have any exercises (local or fallback)
        // Service.exercises returns fallback if empty, so we are "safe" to use,
        // but we should warn user about connection.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin conexión. Usando modo offline.')),
        );
      }
    }
  }

  final List<Widget> _pages = const [
    RutinasScreen(),
    Center(child: Text('Pantalla de Entrenar (WIP)')),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Rutinas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Entrenar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}
