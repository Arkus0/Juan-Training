import '../models/library_exercise.dart';
import 'exercise_library_service.dart';

/// Servicio para manejar sinónimos de ejercicios
///
/// Permite que "banco plano" → "Press de banca", "dominadas" → "Pull-up", etc.
/// Los sinónimos se normalizan a minúsculas sin acentos para matching robusto.
class ExerciseSynonymsService {
  static final ExerciseSynonymsService instance = ExerciseSynonymsService._();
  ExerciseSynonymsService._();

  /// Mapa de sinónimo → nombre canónico en biblioteca
  /// El nombre canónico debe coincidir con el nombre del ejercicio en la BD
  /// NOTA: Muchos ejercicios están en inglés en la BD, estos sinónimos mapean español→inglés
  static final Map<String, String> _synonyms = {
    // ===== ERRORES COMUNES DE VOZ (STT) =====
    // Speech-to-text a menudo confunde palabras similares
    'pres': 'press de banca',
    'prez': 'press de banca',
    'pres de banca': 'press de banca',
    'pres banca': 'press de banca',
    'presa': 'prensa de piernas',
    'banca': 'press de banca',
    'banco': 'press de banca',
    'sentadillas con barra': 'sentadilla con barra',
    'sentadilla': 'sentadilla con barra',
    'sentadia': 'sentadilla con barra',
    'centadilla': 'sentadilla con barra',
    'peso muerte': 'peso muerto convencional',
    'pesmuerto': 'peso muerto convencional',
    'peso muerto': 'peso muerto convencional',
    'jalon': 'jalón al pecho',
    'jalón': 'jalón al pecho',
    'halón': 'jalón al pecho',
    'halon': 'jalón al pecho',
    'remo barra': 'remo inclinado con barra',
    'remobarra': 'remo inclinado con barra',
    'remo con barra': 'remo inclinado con barra',
    'dominada': 'dominadas',
    'curl': 'curl con barra',
    'curls': 'curl con barra',
    'cor': 'curl con barra',
    'extension': 'extensión de triceps',
    'extensión': 'extensión de triceps',
    'extensiones': 'extensión de triceps',
    'militar': 'press militar',
    'press de hombro': 'press de hombro con mancuernas',
    'press de hombros': 'press de hombro con mancuernas',
    'press hombro': 'press de hombro con mancuernas',
    'press hombros': 'press de hombro con mancuernas',
    'laterales': 'elevación lateral con mancuernas',
    'elevaciones laterales': 'elevación lateral con mancuernas',
    'vuelos': 'elevación lateral con mancuernas',
    'fondos': 'fondos en paralelas',
    'fondo': 'fondos en paralelas',
    'plancha abdominal': 'plancha de antebrazo',
    'plancha': 'plancha de antebrazo',
    'abdominales': 'abdominales',
    'abdominal': 'abdominales',

    // ===== ESPAÑOL → NOMBRES EN BD (muchos en inglés) =====

    // -- PECHO --
    'banco plano': 'press de banca',
    'banco inclinado': 'incline dumbbell fly',
    'press plano': 'press de banca',
    'press pecho': 'press de banca',
    'bench press': 'press de banca',
    'aperturas': 'aperturas con mancuernas',
    'fly': 'aperturas con mancuernas',
    'flies': 'aperturas con mancuernas',
    'cruces': 'cruce de poleas para pecho',
    'cruces de polea': 'cruce de poleas para pecho',
    'cruces de poleas': 'cruce de poleas para pecho',
    'crossover': 'cruce de poleas para pecho',
    'cable crossover': 'cruce de poleas para pecho',
    'pecho en maquina': 'press de pecho en máquina',
    'press maquina': 'press de pecho en máquina',
    'flexiones': 'flexiones declinadas',
    'push up': 'incline push up',
    'pushups': 'incline push up',
    'push-up': 'incline push up',
    'lagartijas': 'incline push up',
    'flexiones diamante': 'diamond push ups',

    // -- ESPALDA --
    'dominadas': 'dominadas',
    'pull up': 'dominadas',
    'pull-up': 'dominadas',
    'pullups': 'dominadas',
    'chin up': 'dominadas con agarre supino',
    'chin-up': 'dominadas con agarre supino',
    'chinups': 'dominadas con agarre supino',
    'remo': 'remo con mancuernas',
    'bent over row': 'remo inclinado con barra',
    'remo sentado': 'remo con polea',
    'cable row': 'remo con polea',
    'seated row': 'remo con polea',
    'remo en polea': 'remo con polea',
    'remo polea': 'remo con polea',
    'jalon al pecho': 'jalón al pecho',
    'lat pulldown': 'jalón al pecho',
    'pulldown': 'jalón al pecho',
    'polea alta': 'jalón al pecho',
    'jalon polea': 'jalón al pecho',
    'jalon cerrado': 'jalón al pecho con agarre cerrado',
    'deadlift': 'peso muerto convencional',
    'rumano': 'peso muerto rumano con barra',
    'peso muerto rumano': 'peso muerto rumano con barra',
    'rdl': 'peso muerto rumano con barra',
    'romanian deadlift': 'peso muerto rumano con barra',
    'buenos dias': 'good mornings',
    'buenos días': 'good mornings',
    'good morning': 'good mornings',
    'hiperextensiones': 'hyperextensions',
    'back extension': 'hyperextensions',
    'hip thrust': 'barbell hip thrust',
    'empuje de cadera': 'barbell hip thrust',
    'gluteo': 'glute bridge',
    'glúteo': 'glute bridge',
    'puente de gluteo': 'glute bridge',
    'face pull': 'jalón a la cara',
    'face pulls': 'jalón a la cara',
    'jalon a la cara': 'jalón a la cara',
    'tiron de cara': 'jalón a la cara',
    'pullover': 'pullover con mancuerna',

    // -- PIERNAS --
    'sentadillas': 'sentadilla con disco',
    'squat': 'sentadilla con disco',
    'squats': 'squats on multipress',
    'sentadilla frontal': 'sentadilla frontal',
    'front squat': 'sentadilla frontal',
    'sentadilla bulgara': 'zancadas con mancuernas',
    'sentadilla búlgara': 'zancadas con mancuernas',
    'bulgarian split squat': 'zancadas con mancuernas',
    'zancadas': 'zancadas con barra',
    'lunges': 'zancadas con mancuernas',
    'lunge': 'zancadas con mancuernas',
    'estocadas': 'zancadas con mancuernas',
    'prensa': 'prensa de piernas',
    'leg press': 'prensa de piernas',
    'prensa piernas': 'prensa de piernas',
    'prensa de pierna': 'prensa de piernas',
    'extension cuadriceps': 'curl cuadriceps',
    'extensión cuádriceps': 'curl cuadriceps',
    'leg extension': 'curl cuadriceps',
    'cuadriceps': 'curl cuadriceps',
    'cuádriceps': 'curl cuadriceps',
    'curl femoral': 'curl femoral',
    'leg curl': 'curl femoral',
    'curl de pierna': 'curl femoral',
    'femoral': 'curl femoral',
    'curl isquiotibial': 'curl femoral',
    'isquiotibiales': 'curl femoral',
    'gemelos': 'gemelos en prensa',
    'pantorrillas': 'gemelos en prensa',
    'calf raise': 'gemelos en prensa',
    'elevacion de gemelos': 'gemelos en prensa',
    'sentadilla hack': 'sentadilla hack con barra',
    'hack squat': 'sentadilla hack con barra',

    // -- HOMBROS --
    'press militar': 'press militar',
    'overhead press': 'press militar',
    'shoulder press': 'press de hombro con mancuernas',
    'ohp': 'press militar',
    'press arnold': 'press arnold',
    'arnold press': 'press arnold',
    'lateral raise': 'elevación lateral con mancuernas',
    'vuelos laterales': 'elevación lateral con mancuernas',
    'elevaciones frontales': 'elevaciones frontales',
    'front raise': 'elevaciones frontales',
    'frontales': 'elevaciones frontales',
    'pajaros': 'elevaciones posteriores',
    'pájaros': 'elevaciones posteriores',
    'rear delt': 'rear delt raises',
    'rear delt fly': 'rear delt raises',
    'elevaciones posteriores': 'elevaciones posteriores',
    'encogimientos': 'encogimientos con piernas elevadas',
    'shrugs': 'encogimientos con piernas elevadas',
    'trapecio': 'encogimientos con piernas elevadas',

    // -- BÍCEPS --
    'curl biceps': 'curl con barra',
    'curl bíceps': 'curl con barra',
    'curl de biceps': 'curl con barra',
    'curl de bíceps': 'curl con barra',
    'bicep curl': 'curl con barra',
    'barbell curl': 'curl con barra',
    'curl barra': 'curl con barra',
    'curl con barra': 'curl con barra',
    'biceps': 'curl con barra',
    'bíceps': 'curl con barra',
    'curl mancuernas': 'curl de bíceps con mancuerna',
    'curl con mancuernas': 'curl de bíceps con mancuerna',
    'dumbbell curl': 'curl de bíceps con mancuerna',
    'curl alterno': 'curl de bíceps con mancuerna',
    'curl martillo': 'curl martillo',
    'hammer curl': 'curl martillo',
    'martillo': 'curl martillo',
    'curl predicador': 'preacher curls',
    'preacher curl': 'preacher curls',
    'curl scott': 'preacher curls',
    'predicador': 'preacher curls',
    'curl concentrado': 'dumbbell concentration curl',
    'concentration curl': 'dumbbell concentration curl',
    'curl polea': 'curl de bíceps en polea',
    'cable curl': 'curl de bíceps en polea',
    'curl inclinado': 'curl inclinado con mancuernas',

    // -- TRÍCEPS --
    'extension triceps': 'extensión de triceps',
    'extensión tríceps': 'extensión de triceps',
    'tricep extension': 'extensión de triceps',
    'triceps': 'extensión de triceps',
    'tríceps': 'extensión de triceps',
    'press frances': 'press francés con barra sz',
    'press francés': 'press francés con barra sz',
    'skull crusher': 'press francés con barra sz',
    'skullcrusher': 'press francés con barra sz',
    'skull crushers': 'press francés con barra sz',
    'rompe craneos': 'press francés con barra sz',
    'frances': 'press francés con barra sz',
    'francés': 'press francés con barra sz',
    'fondos triceps': 'fondos entre bancos',
    'dips triceps': 'fondos entre bancos',
    'tricep dips': 'fondos entre bancos',
    'ring dips': 'ring dips',
    'jalon triceps': 'extensión de triceps',
    'jalón tríceps': 'extensión de triceps',
    'pushdown': 'extensión de triceps',
    'tricep pushdown': 'extensión de triceps',
    'triceps polea': 'extensión de triceps',
    'patada de triceps': 'extensión de triceps',
    'patada de tríceps': 'extensión de triceps',
    'tricep kickback': 'extensión de triceps',
    'kickback': 'extensión de triceps',
    'press cerrado': 'press de banca con agarre cerrado',
    'close grip bench': 'press de banca con agarre cerrado',
    'press agarre cerrado': 'press de banca con agarre cerrado',

    // -- CORE / ABDOMINALES --
    'abs': 'abdominales',
    'crunch': 'abdominales',
    'crunches': 'abdominales',
    'sit up': 'abdominales',
    'sit ups': 'abdominales',
    'abdominales en maquina': 'abdominales en máquina',
    'crunch en maquina': 'abdominales en máquina',
    'crunch con cable': 'crunches with cable',
    'crunch polea': 'crunches with cable',
    'plancha lateral': 'plancha de antebrazo',
    'side plank': 'plancha de antebrazo',
    'plank': 'plancha de antebrazo',
    'elevacion piernas': 'levantamiento de piernas',
    'elevación piernas': 'levantamiento de piernas',
    'leg raise': 'levantamiento de piernas',
    'leg raises': 'levantamiento de piernas',
    'elevacion de piernas': 'elevaciones de piernas (colgado)',
    'colgado': 'elevaciones de piernas (colgado)',
    'hanging leg raise': 'elevaciones de piernas (colgado)',
    'russian twist': 'russian twist',
    'giros rusos': 'russian twist',
    'rueda abdominal': 'rollout abdominal con barra',
    'ab wheel': 'rollout abdominal con barra',
    'ab roller': 'rollout abdominal con barra',
    'rollout': 'rollout abdominal con barra',
    'mountain climber': 'mountain climbers',
    'mountain climbers': 'mountain climbers',
    'escaladores': 'mountain climbers',
    'dead bug': 'bicho muerto',
    'hollow body': 'hollow hold',
    'hollow hold': 'hollow hold',
    'leñadores': 'leñadores en polea',
    'woodchop': 'leñadores en polea',
    'wood chop': 'leñadores en polea',

    // -- CARDIO / FUNCIONAL --
    'burpee': 'burpees',
    'burpees': 'burpees',
    'jumping jack': 'polichilenas',
    'jumping jacks': 'polichilenas',
    'saltos tijera': 'polichilenas',
    'polichinelas': 'polichilenas',
    'salto caja': 'saltos al pecho',
    'box jump': 'saltos al pecho',
    'box jumps': 'saltos al pecho',
    'kettlebell swing': 'kettlebell swings',
    'swing kettlebell': 'kettlebell swings',
    'swing': 'kettlebell swings',
    'pesa rusa': 'kettlebell swings',
    'muscle up': 'muscle up',
    'muscle-up': 'muscle up',
    'correr': 'jogging',
    'jogging': 'jogging',
    'trotar': 'jogging',
    'ciclismo': 'ciclismo',
    'bicicleta': 'ciclismo',

    // -- OTROS EJERCICIOS COMUNES --
    'remo con polea baja': 'remo con polea',
    'renegade row': 'renegade row',
    'remo renegado': 'renegade row',
    'high pull': 'high pull',
    'tiron alto': 'high pull',
    'rack pull': 'rack deadlift',
    'pendlay row': 'pendelay rows',
    'pendlay': 'pendelay rows',

    // -- PALABRAS SUELTAS QUE MAPEAN A EJERCICIOS POPULARES --
    'pecho': 'press de banca',
    'espalda': 'dominadas',
    'hombro': 'press militar',
    'hombros': 'press militar',
    'pierna': 'prensa de piernas',
    'piernas': 'prensa de piernas',
  };

  /// Resuelve un sinónimo al nombre canónico
  /// Si no hay sinónimo, devuelve el texto original
  String resolveSynonym(String input) {
    final normalized = _normalizeText(input);
    return _synonyms[normalized] ?? input;
  }

  /// Verifica si existe un sinónimo para el texto dado
  bool hasSynonym(String input) {
    final normalized = _normalizeText(input);
    return _synonyms.containsKey(normalized);
  }

  /// Obtiene el ejercicio de la biblioteca usando sinónimos
  /// Primero intenta resolver el sinónimo, luego busca en la biblioteca
  Future<LibraryExercise?> findExerciseBySynonym(String input) async {
    final canonicalName = resolveSynonym(input);
    final library = ExerciseLibraryService.instance;
    await library.loadLibrary();

    // Buscar por nombre exacto primero
    try {
      return library.exercises.firstWhere(
        (e) => _normalizeText(e.name) == _normalizeText(canonicalName),
      );
    } catch (_) {
      // Si no hay match exacto, buscar por similitud
      final normalized = _normalizeText(canonicalName);
      try {
        return library.exercises.firstWhere(
          (e) =>
              _normalizeText(e.name).contains(normalized) ||
              normalized.contains(_normalizeText(e.name)),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Normaliza texto (minúsculas, sin acentos extra)
  String _normalizeText(String text) {
    return text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Agrega sinónimos personalizados en runtime
  /// Útil para aprendizaje del usuario
  void addCustomSynonym(String synonym, String canonicalName) {
    _synonyms[_normalizeText(synonym)] = canonicalName;
  }

  /// Obtiene todos los sinónimos registrados
  Map<String, String> get allSynonyms => Map.unmodifiable(_synonyms);

  /// Busca sinónimos que contengan cierto texto
  List<MapEntry<String, String>> searchSynonyms(String query) {
    final normalized = _normalizeText(query);
    return _synonyms.entries
        .where(
          (e) => e.key.contains(normalized) || e.value.contains(normalized),
        )
        .toList();
  }
}
