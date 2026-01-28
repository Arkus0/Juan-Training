import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🎯 REDISEÑO Fase 3: Por defecto abre en pestaña ENTRENAR (index 1)
/// Esto reduce fricción cognitiva - el usuario ve directamente qué entrenar hoy.
final bottomNavIndexProvider =
    NotifierProvider<BottomNavIndexNotifier, int>(BottomNavIndexNotifier.new);

class BottomNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void setIndex(int index) {
    state = index;
  }
}
