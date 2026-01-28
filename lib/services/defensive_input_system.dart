/// # Sistema de Validación Defensiva de Entrada
///
/// Este módulo implementa un sistema DEFENSIVO para manejar entrada
/// de OCR y reconocimiento de voz en la aplicación de fitness.
///
/// ## PRINCIPIO FUNDAMENTAL (NO NEGOCIABLE)
///
/// ```
/// OCR y Voz:
/// ❌ NO interpretan
/// ❌ NO deciden
/// ✅ SOLO generan hipótesis
///
/// La app:
/// ✅ Valida
/// ✅ Acota
/// ✅ Corrige
/// ✅ Decide
/// ```
///
/// ## ARQUITECTURA: PIPELINE EN DOS FASES
///
/// ### Fase 1 — Captura bruta (sin semántica)
/// - [RawInputCapture]: Tokens detectados con confianza y posición
/// - NO se interpreta semánticamente
/// - NO se crean ejercicios directamente
///
/// ### Fase 2 — Interpretación acotada
/// - [InputHypothesis]: Hipótesis con candidatos rankeados
/// - [ExerciseHypothesis]: Top N ejercicios de lista cerrada
/// - [SeriesRepsHypothesis]: Parsing conservador (vacío si no está claro)
///
/// ## COMPONENTES PRINCIPALES
///
/// ### Servicios
/// - [DefensiveInputValidationService]: Pipeline principal de validación
/// - [InputContextRestrictionsService]: Restricciones según contexto de uso
/// - [DefensiveMetricsService]: Métricas de UX (no accuracy técnica)
///
/// ### Modelos
/// - [RawInputCapture]: Captura bruta de OCR/Voz
/// - [InputHypothesis]: Hipótesis interpretada
/// - [ReviewableHypothesis]: Estado de revisión para UI
/// - [ReviewSession]: Sesión de revisión múltiple
///
/// ## USO TÍPICO
///
/// ```dart
/// // 1. Inicializar el sistema
/// await DefensiveInputValidationService.instance.initialize();
///
/// // 2. Capturar entrada (Fase 1)
/// final capture = DefensiveInputValidationService.instance.captureFromOcrText(
///   rawText: ocrResult,
///   imageQuality: 0.85,
/// );
///
/// // 3. Interpretar (Fase 2)
/// final hypotheses = await DefensiveInputValidationService.instance.interpretCapture(
///   capture: capture,
///   context: InputContext.routineCreation(),
/// );
///
/// // 4. Crear sesión de revisión
/// final session = ReviewSession.fromHypotheses(hypotheses);
///
/// // 5. Usuario revisa y acepta/corrige/elimina
/// // ... (lógica de UI)
///
/// // 6. Obtener resultados aceptados
/// final accepted = session.acceptedHypotheses;
/// ```
///
/// ## MÉTRICAS CORRECTAS
///
/// El sistema mide:
/// ✅ % de sesiones corregidas sin frustración
/// ✅ % de propuestas aceptadas tras revisión
/// ✅ Tiempo medio de corrección
/// ✅ Abandonos tras OCR/Voz
///
/// NO mide:
/// ❌ % de aciertos del OCR (accuracy técnica)
///
/// ## RESTRICCIONES DE CONTEXTO
///
/// ### En entrenamiento activo:
/// - Solo actuar sobre ejercicio actual o siguiente
/// - Nunca detectar rutinas completas
/// - Nunca añadir ejercicios no visibles
///
/// ### En creación de rutinas:
/// - Puede proponer varios ejercicios
/// - Pero uno por uno, confirmación obligatoria
///
/// ## OBJETIVO FINAL
///
/// Que OCR y voz sean un **asistente torpe pero útil**,
/// no un **autómata confiado que se equivoca**.
library;

export '../models/input_hypothesis.dart';
// Modelos
export '../models/raw_input_capture.dart';
export '../models/reviewable_hypothesis.dart';
// Servicios
export 'defensive_input_validation_service.dart';
export 'defensive_metrics_service.dart';
// Re-exportar tipos necesarios de otros módulos
export 'exercise_matching_service.dart' show MatchSource;
export 'input_context_restrictions_service.dart';
