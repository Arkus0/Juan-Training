import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/services/timer_platform_service.dart';

void main() {
  group('TimerPlatformState', () {
    test('Estado inicial debe ser inactivo', () {
      const state = TimerPlatformState();

      expect(state.isActive, false);
      expect(state.isPaused, false);
      expect(state.remainingSeconds, 0);
    });

    test('remainingSeconds debe calcular tiempo restante correctamente', () {
      final endTime = DateTime.now().add(const Duration(seconds: 30));
      final state = TimerPlatformState(
        isActive: true,
        isPaused: false,
        totalSeconds: 60,
        endTime: endTime,
      );

      // El remaining debe estar cerca de 30 segundos (con tolerancia por tiempo de ejecución)
      expect(state.remainingSeconds, closeTo(30, 1));
    });

    test('remainingSeconds debe retornar totalSeconds cuando está pausado', () {
      const state = TimerPlatformState(
        isActive: true,
        isPaused: true,
        totalSeconds: 45,
        endTime: null,
      );

      expect(state.remainingSeconds, 45);
    });

    test('progress debe calcular correctamente', () {
      final endTime = DateTime.now().add(const Duration(seconds: 45));
      final state = TimerPlatformState(
        isActive: true,
        isPaused: false,
        totalSeconds: 90,
        endTime: endTime,
      );

      // Con 45 segundos restantes de 90 totales, progreso ≈ 0.5
      expect(state.progress, closeTo(0.5, 0.1));
    });

    test('isFinished debe ser true cuando el tiempo terminó', () {
      final endTime = DateTime.now().subtract(const Duration(seconds: 5));
      final state = TimerPlatformState(
        isActive: true,
        isPaused: false,
        totalSeconds: 60,
        endTime: endTime,
      );

      expect(state.isFinished, true);
      expect(state.remainingSeconds, 0);
    });

    test('copyWith debe preservar valores no modificados', () {
      const original = TimerPlatformState(
        isActive: true,
        isPaused: false,
        totalSeconds: 90,
        exerciseIndex: 2,
        setIndex: 1,
      );

      final modified = original.copyWith(isPaused: true);

      expect(modified.isActive, true);
      expect(modified.isPaused, true);
      expect(modified.totalSeconds, 90);
      expect(modified.exerciseIndex, 2);
      expect(modified.setIndex, 1);
    });

    test('copyWith con clearEndTime debe limpiar endTime', () {
      final endTime = DateTime.now().add(const Duration(seconds: 30));
      final original = TimerPlatformState(
        isActive: true,
        endTime: endTime,
      );

      final modified = original.copyWith(clearEndTime: true);

      expect(modified.endTime, isNull);
    });

    group('JSON serialization', () {
      test('toJson y fromJson deben ser inversos', () {
        final endTime = DateTime.now().add(const Duration(seconds: 60));
        final original = TimerPlatformState(
          isActive: true,
          isPaused: false,
          totalSeconds: 90,
          endTime: endTime,
          exerciseIndex: 3,
          setIndex: 2,
        );

        final json = original.toJson();
        final restored = TimerPlatformState.fromJson(json);

        expect(restored.isActive, original.isActive);
        expect(restored.isPaused, original.isPaused);
        expect(restored.totalSeconds, original.totalSeconds);
        expect(restored.exerciseIndex, original.exerciseIndex);
        expect(restored.setIndex, original.setIndex);
        // endTime puede tener pequeña diferencia por milisegundos
        expect(
          restored.endTime?.millisecondsSinceEpoch,
          original.endTime?.millisecondsSinceEpoch,
        );
      });

      test('fromJson debe manejar valores null gracefully', () {
        final json = <String, dynamic>{
          'isActive': true,
          // Otros campos null
        };

        final state = TimerPlatformState.fromJson(json);

        expect(state.isActive, true);
        expect(state.isPaused, false);
        expect(state.totalSeconds, 90);
        expect(state.endTime, isNull);
      });
    });
  });

  group('TimerPlatformEvent', () {
    test('Debe tener todos los eventos necesarios', () {
      expect(TimerPlatformEvent.values, contains(TimerPlatformEvent.pause));
      expect(TimerPlatformEvent.values, contains(TimerPlatformEvent.resume));
      expect(TimerPlatformEvent.values, contains(TimerPlatformEvent.skip));
      expect(TimerPlatformEvent.values, contains(TimerPlatformEvent.add30));
      expect(TimerPlatformEvent.values, contains(TimerPlatformEvent.finished));
    });
  });
}
