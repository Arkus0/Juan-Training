import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../models/input_hypothesis.dart';
import 'defensive_input_validation_service.dart';

/// Servicio de Restricciones de Contexto para Entrada
///
/// ## PRINCIPIO: Evitar "locuras"
///
/// El sistema de entrada (OCR/Voz) tiene tendencia a:
/// - Detectar más ejercicios de los que existen
/// - Proponer cambios a ejercicios que el usuario no está viendo
/// - Añadir ejercicios aleatorios a la rutina
///
/// Este servicio ACOTA lo que el sistema puede hacer según el contexto.
///
/// ## REGLAS POR CONTEXTO
///
/// ### En entrenamiento activo:
/// - Solo actuar sobre ejercicio actualmente abierto
/// - O el siguiente ejercicio (si está visible)
/// - NUNCA detectar rutinas completas
/// - NUNCA añadir ejercicios no visibles
///
/// ### En creación de rutinas:
/// - Puede proponer varios ejercicios
/// - Pero UNO POR UNO
/// - Confirmación OBLIGATORIA
class InputContextRestrictionsService {
  static final InputContextRestrictionsService instance =
      InputContextRestrictionsService._();
  InputContextRestrictionsService._();

  final _logger = Logger();

  // Estado actual del contexto
  InputContext? _currentContext;
  List<String> _visibleExerciseIds = [];
  String? _activeExerciseId;
  AppScreen _currentScreen = AppScreen.unknown;

  // =========================================
  // CONFIGURACIÓN DE CONTEXTO
  // =========================================

  /// Establece el contexto actual
  void setContext(InputContext context) {
    _currentContext = context;
    _logger.d('Contexto establecido: ${context.mode}');
  }

  /// Actualiza la pantalla actual
  void setCurrentScreen(AppScreen screen) {
    _currentScreen = screen;
    _logger.d('Pantalla actual: $screen');
  }

  /// Actualiza los ejercicios visibles en la UI
  void setVisibleExercises(List<String> exerciseIds) {
    _visibleExerciseIds = exerciseIds;
    _logger.d('Ejercicios visibles: ${exerciseIds.length}');
  }

  /// Establece el ejercicio actualmente activo/enfocado
  void setActiveExercise(String? exerciseId) {
    _activeExerciseId = exerciseId;
    _logger.d('Ejercicio activo: $exerciseId');
  }

  // =========================================
  // VALIDACIÓN DE RESTRICCIONES
  // =========================================

  /// Obtiene el contexto actual o uno por defecto restrictivo
  InputContext get currentContext {
    if (_currentContext != null) return _currentContext!;

    // Inferir contexto de la pantalla
    return _inferContextFromScreen();
  }

  /// Infiere el contexto basado en la pantalla actual
  InputContext _inferContextFromScreen() {
    switch (_currentScreen) {
      case AppScreen.activeWorkout:
        return InputContext.activeWorkout(
          currentExerciseId: _activeExerciseId ?? '',
        );
      case AppScreen.routineEditor:
      case AppScreen.routineCreation:
        return InputContext.routineCreation();
      case AppScreen.exerciseDetail:
        return InputContext.singleEdit(
          exerciseId: _activeExerciseId ?? '',
        );
      default:
        // Por defecto, ser muy restrictivo
        return const InputContext(
          mode: InputMode.singleExerciseEdit,
          maxExercisesAllowed: 1,
        );
    }
  }

  /// Valida si una hipótesis está permitida en el contexto actual
  RestrictionValidation validateHypothesis(InputHypothesis hypothesis) {
    final context = currentContext;
    final violations = <RestrictionViolation>[];

    // Validación 1: Número de ejercicios
    // (Ya aplicada en DefensiveInputValidationService)

    // Validación 2: En entrenamiento activo, solo ejercicio actual/siguiente
    if (context.mode == InputMode.activeWorkout) {
      final topCandidate = hypothesis.topExerciseCandidate;
      if (topCandidate != null) {
        final exerciseId = topCandidate.exercise.id.toString();
        if (!_isExerciseAllowedInActiveWorkout(exerciseId)) {
          violations.add(
            const RestrictionViolation(
              type: ViolationType.exerciseNotVisible,
              message:
                  'Este ejercicio no está visible en el entrenamiento actual',
              severity: ViolationSeverity.block,
            ),
          );
        }
      }
    }

    // Validación 3: En edición single, verificar que es el ejercicio correcto
    if (context.mode == InputMode.singleExerciseEdit) {
      if (_activeExerciseId != null) {
        final topCandidate = hypothesis.topExerciseCandidate;
        if (topCandidate != null) {
          final exerciseId = topCandidate.exercise.id.toString();
          if (exerciseId != _activeExerciseId) {
            violations.add(
              RestrictionViolation(
                type: ViolationType.differentExercise,
                message:
                    'Se detectó un ejercicio diferente al que está editando',
                severity: ViolationSeverity.warn,
                suggestion:
                    '¿Quizás quiso editar ${topCandidate.exercise.name}?',
              ),
            );
          }
        }
      }
    }

    // Validación 4: Verificar que no hay valores absurdos
    final seriesReps = hypothesis.seriesRepsHypothesis;
    if (seriesReps.series?.value != null && seriesReps.series!.value > 10) {
      violations.add(
        RestrictionViolation(
          type: ViolationType.suspiciousValue,
          message: '${seriesReps.series!.value} series parece excesivo',
          severity: ViolationSeverity.warn,
          suggestion:
              '¿Quizás el número de series es ${seriesReps.series!.value % 10}?',
        ),
      );
    }

    return RestrictionValidation(
      isAllowed: !violations.any((v) => v.severity == ViolationSeverity.block),
      violations: violations,
      appliedContext: context,
    );
  }

  /// Verifica si un ejercicio está permitido en entrenamiento activo
  bool _isExerciseAllowedInActiveWorkout(String exerciseId) {
    if (_visibleExerciseIds.isEmpty) {
      return true; // Sin restricción si no hay info
    }
    return _visibleExerciseIds.contains(exerciseId);
  }

  /// Obtiene restricciones como texto para mostrar al usuario
  List<String> getActiveRestrictionsDescription() {
    final context = currentContext;
    final restrictions = <String>[];

    switch (context.mode) {
      case InputMode.activeWorkout:
        restrictions.add('Solo puedes modificar el ejercicio actual');
        restrictions.add('No se pueden añadir nuevos ejercicios');
        break;
      case InputMode.routineCreation:
        restrictions.add('Cada ejercicio requiere confirmación');
        restrictions.add(
            'Máximo ${context.maxExercisesAllowed} ejercicios por escaneo',);
        break;
      case InputMode.singleExerciseEdit:
        restrictions.add('Solo se puede editar este ejercicio');
        break;
    }

    return restrictions;
  }

  // =========================================
  // ACCIONES PERMITIDAS
  // =========================================

  /// Verifica si se permite añadir ejercicios nuevos
  bool get canAddNewExercises {
    final context = currentContext;
    return context.mode == InputMode.routineCreation;
  }

  /// Verifica si se permite modificar series/reps
  bool get canModifySeriesReps {
    return true; // Siempre permitido con confirmación
  }

  /// Verifica si se permite escanear múltiples ejercicios
  bool get canScanMultipleExercises {
    final context = currentContext;
    return context.mode == InputMode.routineCreation &&
        context.maxExercisesAllowed > 1;
  }

  /// Número máximo de ejercicios permitidos en el contexto actual
  int get maxExercisesAllowed => currentContext.maxExercisesAllowed;
}

// =========================================
// MODELOS
// =========================================

/// Resultado de validación de restricciones
@immutable
class RestrictionValidation {
  /// Si la hipótesis está permitida
  final bool isAllowed;

  /// Lista de violaciones encontradas
  final List<RestrictionViolation> violations;

  /// Contexto aplicado
  final InputContext appliedContext;

  const RestrictionValidation({
    required this.isAllowed,
    required this.violations,
    required this.appliedContext,
  });

  /// Violaciones bloqueantes
  List<RestrictionViolation> get blockingViolations =>
      violations.where((v) => v.severity == ViolationSeverity.block).toList();

  /// Advertencias (no bloqueantes)
  List<RestrictionViolation> get warnings =>
      violations.where((v) => v.severity == ViolationSeverity.warn).toList();

  /// Si hay advertencias que mostrar
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Violación de restricción individual
@immutable
class RestrictionViolation {
  /// Tipo de violación
  final ViolationType type;

  /// Mensaje para el usuario
  final String message;

  /// Severidad
  final ViolationSeverity severity;

  /// Sugerencia para corregir
  final String? suggestion;

  const RestrictionViolation({
    required this.type,
    required this.message,
    required this.severity,
    this.suggestion,
  });
}

/// Tipos de violación
enum ViolationType {
  /// Ejercicio no visible en el contexto actual
  exerciseNotVisible,

  /// Ejercicio diferente al que se está editando
  differentExercise,

  /// Demasiados ejercicios para el contexto
  tooManyExercises,

  /// Valor sospechoso (probablemente error de parsing)
  suspiciousValue,

  /// Acción no permitida en este contexto
  actionNotAllowed,
}

/// Severidad de la violación
enum ViolationSeverity {
  /// Bloquea la acción completamente
  block,

  /// Advierte pero permite continuar
  warn,

  /// Solo informativo
  info,
}

/// Pantallas de la app para inferir contexto
enum AppScreen {
  /// Pantalla de entrenamiento activo
  activeWorkout,

  /// Editor de rutina existente
  routineEditor,

  /// Creación de nueva rutina
  routineCreation,

  /// Detalle de ejercicio
  exerciseDetail,

  /// Biblioteca de ejercicios
  exerciseLibrary,

  /// Otra pantalla / desconocido
  unknown,
}
