// ============================================================================
// APP STRINGS — Centralización de textos
// ============================================================================
//
// Este archivo centraliza los strings hardcodeados de la app.
//
// BENEFICIOS:
// 1. Mantenibilidad: Un solo lugar para cambiar textos
// 2. Consistencia: Mismos textos en toda la app
// 3. i18n-ready: Facilita futura internacionalización
// 4. Performance: const strings son más eficientes
// 5. Typo-proof: Menos errores de escritura
//
// USO:
// ```dart
// import 'package:juan_training/utils/app_strings.dart';
// Text(AppStrings.sessionComplete)
// ```
// ============================================================================

/// Strings centralizados de la aplicación
abstract class AppStrings {
  // ═══════════════════════════════════════════════════════════════════════════
  // SESIÓN DE ENTRENAMIENTO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Títulos de sesión
  static const sessionActive = 'SESIÓN ACTIVA';
  static const sessionComplete = 'SESIÓN COMPLETADA';
  static const sessionDiscard = 'DESCARTAR SESIÓN';
  static const sessionSave = 'GUARDAR SESIÓN';
  static const sessionResume = 'REANUDAR SESIÓN';

  /// Mensajes de sesión
  static const sessionDiscardConfirm =
      '¿Estás seguro de que quieres descartar la sesión actual sin guardarla?';
  static const sessionSavedSuccess = 'Sesión guardada correctamente';
  static const sessionEmpty = 'No hay series registradas';

  // ═══════════════════════════════════════════════════════════════════════════
  // TIMER DE DESCANSO
  // ═══════════════════════════════════════════════════════════════════════════

  static const restTimer = 'DESCANSO';
  static const restTimerStart = 'Iniciar descanso';
  static const restTimerSkip = 'Saltar descanso';
  static const restTimerAdd30 = '+30 segundos';
  static const restTimerPaused = 'PAUSADO';
  static const restTimerResting = 'DESCANSANDO';
  static const restTimerTapToPause = 'Toca para pausar';
  static const restTimerTapToResume = 'Toca para reanudar';
  static const restTimerRestart = 'Reiniciar descanso';

  // ═══════════════════════════════════════════════════════════════════════════
  // PROGRESIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  static const progressionIncrease = 'SUBIR PESO';
  static const progressionIncreaseReps = 'SUBIR REPS';
  static const progressionMaintain = 'OBJETIVO HOY';
  static const progressionConsolidate = 'CONSOLIDAR';
  static const progressionAdjust = 'AJUSTAR';

  /// Mensajes de consecuencia
  static const progressionIfSuccess = 'Si éxito:';
  static const progressionRepeatToConfirm = 'Repite para confirmar subida';
  static const progressionSameGoal = 'Mismo objetivo hoy';
  static const progressionReducedForRecovery = 'Peso reducido para recuperar';
  static const progressionConsolidatingBase = 'Consolidando base';

  /// Badges
  static const progressionImprovement = '↑ MEJORA';
  static const progressionDeload = 'DELOAD';
  static const progressionProtected = 'PROTEGIDO';

  // ═══════════════════════════════════════════════════════════════════════════
  // FEEDBACK EMPÁTICO (días difíciles)
  // ═══════════════════════════════════════════════════════════════════════════

  static const empatheticNoWorries = 'No pasa nada';
  static const empatheticItHappens = 'Ocurre, forma parte del proceso';
  static const empatheticResuming = 'Retomamos donde lo dejaste';
  static const empatheticConsolidating = 'Estás consolidando';
  static const empatheticBodyNeedsRest = 'Tu cuerpo pide recuperarse';
  static const empatheticCompleteWhatYouCan =
      'Completa lo que puedas. La consistencia importa más.';
  static const empatheticNextSetDifferent =
      'El próximo set puede ser diferente.';
  static const empatheticSystemRemembers = 'El sistema recuerda tu progreso.';
  static const empatheticBodyAdapts = 'El cuerpo adapta antes de avanzar.';
  static const empatheticRestIsTraining = 'Descansar también es entrenar.';

  // ═══════════════════════════════════════════════════════════════════════════
  // EJERCICIO
  // ═══════════════════════════════════════════════════════════════════════════

  static const exerciseComplete = 'Ejercicio completado';
  static const exerciseGoalMet = '¡Objetivo cumplido!';
  static const exerciseHistory = 'Ver Historial';
  static const exerciseAlternatives = 'Ver Alternativas';
  static const exerciseNotes = 'Notas del Ejercicio';
  static const exerciseNoAlternatives = 'Sin alternativas registradas';
  static const exerciseNoHistory = 'No hay datos previos.';
  static const exerciseLastSession = 'ÚLTIMA SESIÓN:';
  static const exerciseAddSet = '+ Añadir serie';

  // ═══════════════════════════════════════════════════════════════════════════
  // NUMPAD / INPUT
  // ═══════════════════════════════════════════════════════════════════════════

  static const inputConfirm = 'CONFIRMAR';
  static const inputClear = 'LIMPIAR';
  static const inputPrevious = 'Anterior:';
  static const inputUse = 'USAR';
  static const inputCalculatePlates = 'Calcular discos';
  static const inputSetOf = 'SERIE %d DE %d';

  /// Límites
  static const inputMaxWeightReached = 'Máximo: 999.9 kg';
  static const inputMaxRepsReached = 'Máximo: 999 reps';

  // ═══════════════════════════════════════════════════════════════════════════
  // RUTINAS
  // ═══════════════════════════════════════════════════════════════════════════

  static const routineCreate = 'CREAR RUTINA';
  static const routineEdit = 'EDITAR RUTINA';
  static const routineDelete = 'Eliminar rutina';
  static const routineDeleteConfirm = '¿Eliminar esta rutina?';
  static const routineSave = 'GUARDAR';
  static const routineCancel = 'CANCELAR';
  static const routineDay = 'DÍA';
  static const routineAddDay = 'Añadir día';
  static const routineAddExercise = 'Añadir ejercicio';
  static const routineImport = 'Importar rutina';
  static const routineExport = 'Exportar rutina';

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVEGACIÓN / TABS
  // ═══════════════════════════════════════════════════════════════════════════

  static const navRoutines = 'RUTINAS';
  static const navTrain = 'ENTRENAR';
  static const navAnalysis = 'ANÁLISIS';
  static const navSettings = 'AJUSTES';

  // ═══════════════════════════════════════════════════════════════════════════
  // ANÁLISIS
  // ═══════════════════════════════════════════════════════════════════════════

  static const analysisNoData = 'Sin datos suficientes';
  static const analysisStreak = 'Racha actual';
  static const analysisVolume = 'Volumen total';
  static const analysisPRs = 'Records personales';
  static const analysisActivity = 'Actividad';

  // ═══════════════════════════════════════════════════════════════════════════
  // AJUSTES
  // ═══════════════════════════════════════════════════════════════════════════

  static const settingsGeneral = 'General';
  static const settingsTimer = 'Timer de descanso';
  static const settingsVibration = 'Vibración';
  static const settingsSound = 'Sonido';
  static const settingsLockScreen = 'Timer en pantalla bloqueada';
  static const settingsVoice = 'Entrada por voz';
  static const settingsAbout = 'Acerca de';

  // ═══════════════════════════════════════════════════════════════════════════
  // COMUNES
  // ═══════════════════════════════════════════════════════════════════════════

  static const ok = 'OK';
  static const cancel = 'CANCELAR';
  static const save = 'GUARDAR';
  static const delete = 'ELIMINAR';
  static const close = 'CERRAR';
  static const back = 'VOLVER';
  static const next = 'SIGUIENTE';
  static const done = 'HECHO';
  static const loading = 'Cargando...';
  static const error = 'Error';
  static const success = 'Éxito';
  static const warning = 'Advertencia';

  // ═══════════════════════════════════════════════════════════════════════════
  // UNIDADES
  // ═══════════════════════════════════════════════════════════════════════════

  static const unitKg = 'kg';
  static const unitReps = 'reps';
  static const unitSets = 'series';
  static const unitSeconds = 's';
  static const unitMinutes = 'min';

  // ═══════════════════════════════════════════════════════════════════════════
  // CELEBRACIONES / MILESTONES
  // ═══════════════════════════════════════════════════════════════════════════

  static const celebrationPR = '¡NUEVO RÉCORD PERSONAL!';
  static const celebrationImproved = '¡HAS SUPERADO LA SESIÓN ANTERIOR!';
  static const celebrationHalfway = '¡50% completado!';
  static const celebrationAlmostDone = '¡75% completado!';
  static const celebrationComplete = '¡Sesión completada!';
}

/// Formateador de strings con parámetros
class AppStringFormatter {
  /// Formatea "SERIE X DE Y"
  static String setOf(int current, int total) => 'SERIE $current DE $total';

  /// Formatea peso con kg
  static String weight(double kg) {
    if (kg == kg.roundToDouble()) {
      return '${kg.toInt()}kg';
    }
    return '${kg.toStringAsFixed(1)}kg';
  }

  /// Formatea "X reps"
  static String reps(int count) => '$count reps';

  /// Formatea tiempo de descanso
  static String restTime(int seconds) => '${seconds}s';

  /// Formatea porcentaje de progreso
  static String progress(double percentage) => '${(percentage * 100).round()}%';
}
