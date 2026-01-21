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
  bool _isInitialConnection = true;

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
    // Check if there is any active connection (mobile, wifi, ethernet, vpn, bluetooth, etc.)
    // If the list contains .none, it usually means no connection, but we check for presence of ANY valid connection.
    final hasConnection = results.any((result) => result != ConnectivityResult.none);

    if (!_isInitialConnection) {
      _showSnackBar(hasConnection ? 'Conexión recuperada.' : 'Conexión perdida.');
    }
    _isInitialConnection = false;

    if (hasConnection) {
      _checkLibrarySync();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.red[900], // Aggressive red snackbar
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.redAccent[700]!, width: 1),
        ),
      ),
    );
  }

  Future<void> _checkLibrarySync() async {
    final service = ExerciseLibraryService.instance;
    if (await service.shouldSync()) {
      if (!mounted) return;
      final success = await service.syncLibrary();
      if (!mounted) return;

      if (success) {
        _showSnackBar('Biblioteca actualizada.');
      }
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
