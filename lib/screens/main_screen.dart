import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/main_provider.dart';
import '../services/exercise_library_service.dart';
import 'rutinas_screen.dart';
import 'train_selection_screen.dart';
import 'history_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLibrarySync();
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    // Ignore the very first event if it happens immediately, as we handle startup sync separately
    if (_isFirstLoad) {
      _isFirstLoad = false;
      return;
    }

    final hasConnection = results.any((r) => r != ConnectivityResult.none);

    if (hasConnection) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conexión recuperada.')),
      );
      _checkLibrarySync();
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conexión perdida.')),
      );
    }
  }

  Future<void> _checkLibrarySync() async {
    final service = ExerciseLibraryService.instance;
    if (await service.shouldSync()) {
      if (!mounted) return;

      // Only show "Actualizando" if we are manually triggering or it's a significant sync
      // But per user request, we mostly want to notify on connection change.
      // We'll keep it subtle.

      final success = await service.syncLibrary();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biblioteca actualizada.')),
        );
      }
      // If failed, we don't spam "Sin conexión" here because the connectivity listener handles that,
      // or we are just in offline mode silently.
    }
  }

  final List<Widget> _pages = const [
    RutinasScreen(),
    TrainSelectionScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(bottomNavIndexProvider.notifier).state = index;
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
