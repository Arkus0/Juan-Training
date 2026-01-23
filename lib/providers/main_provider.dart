import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🎯 REDISEÑO Fase 3: Por defecto abre en pestaña ENTRENAR (index 1)
/// Esto reduce fricción cognitiva - el usuario ve directamente qué entrenar hoy.
final bottomNavIndexProvider = StateProvider<int>((ref) => 1);
