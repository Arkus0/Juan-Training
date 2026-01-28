import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ps_sesion.dart';
import '../models/ps_ejercicio.dart';
import '../models/ps_serie_log.dart';

/// Estado simple para el ejemplo: mantiene si hay una sesión activa y, cuando se finaliza, guarda la sesión en `lastSession`.
class PSTrainingState {
  final bool active;
  final PSSesion? activeSession;
  final PSSesion? lastSession;

  const PSTrainingState._({required this.active, this.activeSession, this.lastSession});

  factory PSTrainingState.idle() => const PSTrainingState._(active: false);
  factory PSTrainingState.active(PSSesion s) => PSTrainingState._(active: true, activeSession: s);
  factory PSTrainingState.finished(PSSesion last) => PSTrainingState._(active: false, lastSession: last);
}

class PSTrainingController extends Notifier<PSTrainingState> {
  @override
  PSTrainingState build() => PSTrainingState.idle();

  void startSession({required String id, String? rutinaId}) {
    state = PSTrainingState.active(PSSesion(id: id, fecha: DateTime.now(), durationSeconds: null, totalVolume: 0.0, ejerciciosCompletados: [], rutinaId: rutinaId));
  }

  void addSet({required String ejercicioId, required double peso, required int reps, int? rpe}) {
    final s = state.activeSession;
    if (s == null) return;
    final ejercicio = s.ejerciciosCompletados.firstWhere((e) => e.id == ejercicioId, orElse: () => PSEjercicio(id: ejercicioId, nombre: ejercicioId));
    ejercicio.logs.add(PSSerieLog(peso: peso, reps: reps, rpe: rpe));
    // recompute volume simplificado
    final newTotal = s.ejerciciosCompletados.fold(0.0, (sum, e) => sum + e.logs.where((l) => l.completed).fold(0.0, (vol, l) => vol + l.peso * l.reps));
    final updated = PSSesion(id: s.id, fecha: s.fecha, durationSeconds: s.durationSeconds, totalVolume: newTotal, ejerciciosCompletados: s.ejerciciosCompletados, rutinaId: s.rutinaId);
    state = PSTrainingState.active(updated);
  }

  void finishSession() {
    final s = state.activeSession;
    if (s == null) return;
    // set duration simplistic
    final finished = PSSesion(id: s.id, fecha: s.fecha, durationSeconds: 1800, totalVolume: s.totalVolume, ejerciciosCompletados: s.ejerciciosCompletados, rutinaId: s.rutinaId);
    state = PSTrainingState.finished(finished);
  }

  void undoLastSet() {
    final s = state.activeSession;
    if (s == null) return;
    if (s.ejerciciosCompletados.isEmpty) return;
    final lastEj = s.ejerciciosCompletados.last;
    if (lastEj.logs.isNotEmpty) {
      lastEj.logs.removeLast();
      final newTotal = s.ejerciciosCompletados.fold(0.0, (sum, e) => sum + e.logs.where((l) => l.completed).fold(0.0, (vol, l) => vol + l.peso * l.reps));
      final updated = PSSesion(id: s.id, fecha: s.fecha, durationSeconds: s.durationSeconds, totalVolume: newTotal, ejerciciosCompletados: s.ejerciciosCompletados, rutinaId: s.rutinaId);
      state = PSTrainingState.active(updated);
    }
  }
}

final psTrainingControllerProvider = NotifierProvider<PSTrainingController, PSTrainingState>(() => PSTrainingController());
