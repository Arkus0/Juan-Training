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
  static final Map<String, String> _synonyms = {
    // ===== PECHO =====
    'banco plano': 'press de banca',
    'banco inclinado': 'press inclinado con barra',
    'banco declinado': 'press declinado con barra',
    'press plano': 'press de banca',
    'press pecho': 'press de banca',
    'bench press': 'press de banca',
    'aperturas': 'aperturas con mancuernas',
    'fly': 'aperturas con mancuernas',
    'flies': 'aperturas con mancuernas',
    'cruces': 'cruce de poleas',
    'cruces de polea': 'cruce de poleas',
    'crossover': 'cruce de poleas',
    'fondos': 'fondos en paralelas',
    'dips': 'fondos en paralelas',
    'flexiones': 'flexiones',
    'push up': 'flexiones',
    'pushups': 'flexiones',
    'push-up': 'flexiones',
    'lagartijas': 'flexiones',

    // ===== ESPALDA =====
    'dominadas': 'dominadas',
    'pull up': 'dominadas',
    'pull-up': 'dominadas',
    'pullups': 'dominadas',
    'chin up': 'dominadas agarre supino',
    'chin-up': 'dominadas agarre supino',
    'chinups': 'dominadas agarre supino',
    'remo': 'remo con barra',
    'remo con barra': 'remo con barra',
    'bent over row': 'remo con barra',
    'remo sentado': 'remo en polea baja',
    'cable row': 'remo en polea baja',
    'seated row': 'remo en polea baja',
    'jalon': 'jalon al pecho',
    'jalón': 'jalon al pecho',
    'lat pulldown': 'jalon al pecho',
    'pulldown': 'jalon al pecho',
    'polea alta': 'jalon al pecho',
    'jalon polea': 'jalon al pecho',
    'peso muerto': 'peso muerto',
    'deadlift': 'peso muerto',
    'rumano': 'peso muerto rumano',
    'peso muerto rumano': 'peso muerto rumano',
    'rdl': 'peso muerto rumano',
    'romanian deadlift': 'peso muerto rumano',
    'buenos dias': 'buenos días',
    'good morning': 'buenos días',
    'hiperextensiones': 'hiperextensiones',
    'back extension': 'hiperextensiones',
    
    // ===== PIERNAS =====
    'sentadilla': 'sentadilla con barra',
    'sentadillas': 'sentadilla con barra',
    'squat': 'sentadilla con barra',
    'squats': 'sentadilla con barra',
    'sentadilla frontal': 'sentadilla frontal',
    'front squat': 'sentadilla frontal',
    'sentadilla bulgara': 'sentadilla búlgara',
    'sentadilla búlgara': 'sentadilla búlgara',
    'bulgarian split squat': 'sentadilla búlgara',
    'zancadas': 'zancadas',
    'lunges': 'zancadas',
    'lunge': 'zancadas',
    'estocadas': 'zancadas',
    'prensa': 'prensa de piernas',
    'leg press': 'prensa de piernas',
    'prensa piernas': 'prensa de piernas',
    'prensa de pierna': 'prensa de piernas',
    'extension cuadriceps': 'extensión de cuádriceps',
    'extensión cuádriceps': 'extensión de cuádriceps',
    'leg extension': 'extensión de cuádriceps',
    'curl femoral': 'curl femoral',
    'leg curl': 'curl femoral',
    'curl de pierna': 'curl femoral',
    'femoral': 'curl femoral',
    'curl isquiotibial': 'curl femoral',
    'hip thrust': 'hip thrust',
    'empuje de cadera': 'hip thrust',
    'elevacion de pantorrilla': 'elevación de gemelos',
    'gemelos': 'elevación de gemelos',
    'calf raise': 'elevación de gemelos',
    'pantorrillas': 'elevación de gemelos',
    'gemelo de pie': 'elevación de gemelos de pie',
    'gemelo sentado': 'elevación de gemelos sentado',
    
    // ===== HOMBROS =====
    'press militar': 'press militar',
    'press hombro': 'press militar',
    'press hombros': 'press militar',
    'overhead press': 'press militar',
    'shoulder press': 'press militar',
    'ohp': 'press militar',
    'press arnold': 'press arnold',
    'arnold press': 'press arnold',
    'elevaciones laterales': 'elevaciones laterales',
    'lateral raise': 'elevaciones laterales',
    'laterales': 'elevaciones laterales',
    'vuelos laterales': 'elevaciones laterales',
    'elevaciones frontales': 'elevaciones frontales',
    'front raise': 'elevaciones frontales',
    'frontales': 'elevaciones frontales',
    'pajaros': 'pájaros',
    'pájaros': 'pájaros',
    'rear delt fly': 'pájaros',
    'elevaciones posteriores': 'pájaros',
    'face pull': 'face pull',
    'face pulls': 'face pull',
    'tiron de cara': 'face pull',
    'encogimientos': 'encogimientos de hombros',
    'shrugs': 'encogimientos de hombros',
    'trapecio': 'encogimientos de hombros',
    
    // ===== BRAZOS (BÍCEPS) =====
    'curl biceps': 'curl de bíceps con barra',
    'curl bíceps': 'curl de bíceps con barra',
    'curl de biceps': 'curl de bíceps con barra',
    'curl de bíceps': 'curl de bíceps con barra',
    'bicep curl': 'curl de bíceps con barra',
    'barbell curl': 'curl de bíceps con barra',
    'curl barra': 'curl de bíceps con barra',
    'curl con barra': 'curl de bíceps con barra',
    'curl mancuernas': 'curl de bíceps con mancuernas',
    'curl con mancuernas': 'curl de bíceps con mancuernas',
    'dumbbell curl': 'curl de bíceps con mancuernas',
    'curl alterno': 'curl de bíceps alterno',
    'curl martillo': 'curl martillo',
    'hammer curl': 'curl martillo',
    'curl predicador': 'curl predicador',
    'preacher curl': 'curl predicador',
    'curl scott': 'curl predicador',
    'curl concentrado': 'curl concentrado',
    'concentration curl': 'curl concentrado',
    'curl polea': 'curl de bíceps en polea',
    'cable curl': 'curl de bíceps en polea',
    
    // ===== BRAZOS (TRÍCEPS) =====
    'extension triceps': 'extensión de tríceps',
    'extensión tríceps': 'extensión de tríceps',
    'tricep extension': 'extensión de tríceps',
    'press frances': 'press francés',
    'press francés': 'press francés',
    'skull crusher': 'press francés',
    'skullcrusher': 'press francés',
    'skull crushers': 'press francés',
    'rompe craneos': 'press francés',
    'fondos triceps': 'fondos en banco',
    'dips triceps': 'fondos en banco',
    'tricep dips': 'fondos en banco',
    'jalon triceps': 'extensión de tríceps en polea',
    'jalón tríceps': 'extensión de tríceps en polea',
    'pushdown': 'extensión de tríceps en polea',
    'tricep pushdown': 'extensión de tríceps en polea',
    'triceps polea': 'extensión de tríceps en polea',
    'patada de triceps': 'patada de tríceps',
    'patada de tríceps': 'patada de tríceps',
    'tricep kickback': 'patada de tríceps',
    'kickback': 'patada de tríceps',
    'press cerrado': 'press de banca agarre cerrado',
    'close grip bench': 'press de banca agarre cerrado',
    'press agarre cerrado': 'press de banca agarre cerrado',
    
    // ===== CORE / ABDOMINALES =====
    'abdominales': 'crunch abdominal',
    'abs': 'crunch abdominal',
    'crunch': 'crunch abdominal',
    'crunches': 'crunch abdominal',
    'sit up': 'crunch abdominal',
    'sit ups': 'crunch abdominal',
    'plancha': 'plancha',
    'plank': 'plancha',
    'plancha lateral': 'plancha lateral',
    'side plank': 'plancha lateral',
    'elevacion piernas': 'elevación de piernas',
    'elevación piernas': 'elevación de piernas',
    'leg raise': 'elevación de piernas',
    'leg raises': 'elevación de piernas',
    'russian twist': 'russian twist',
    'giros rusos': 'russian twist',
    'rueda abdominal': 'rueda abdominal',
    'ab wheel': 'rueda abdominal',
    'ab roller': 'rueda abdominal',
    'mountain climber': 'mountain climbers',
    'mountain climbers': 'mountain climbers',
    'escaladores': 'mountain climbers',
    'dead bug': 'dead bug',
    'hollow body': 'hollow body hold',
    'hollow hold': 'hollow body hold',
    
    // ===== CARDIO / FUNCIONAL =====
    'burpee': 'burpees',
    'burpees': 'burpees',
    'jumping jack': 'jumping jacks',
    'jumping jacks': 'jumping jacks',
    'saltos tijera': 'jumping jacks',
    'salto caja': 'salto al cajón',
    'box jump': 'salto al cajón',
    'box jumps': 'salto al cajón',
    'salto cajón': 'salto al cajón',
    'kettlebell swing': 'kettlebell swing',
    'swing kettlebell': 'kettlebell swing',
    'swing': 'kettlebell swing',
    'thrusters': 'thrusters',
    'thruster': 'thrusters',
    'clean': 'clean',
    'cargada': 'clean',
    'clean and jerk': 'clean and jerk',
    'snatch': 'snatch',
    'arrancada': 'snatch',
    'farmer walk': 'farmer walk',
    'paseo granjero': 'farmer walk',
    'farmer carry': 'farmer walk',
    'battle rope': 'battle ropes',
    'battle ropes': 'battle ropes',
    'cuerdas': 'battle ropes',
    'remo maquina': 'remo en máquina',
    'rowing machine': 'remo en máquina',
    
    // ===== VARIACIONES COMUNES DE ESCRITURA =====
    'biceps': 'curl de bíceps con barra',
    'bíceps': 'curl de bíceps con barra',
    'triceps': 'extensión de tríceps',
    'tríceps': 'extensión de tríceps',
    'cuadriceps': 'extensión de cuádriceps',
    'cuádriceps': 'extensión de cuádriceps',
    'espalda': 'remo con barra',
    'pecho': 'press de banca',
    'hombro': 'press militar',
    'hombros': 'press militar',
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
          (e) => _normalizeText(e.name).contains(normalized) ||
                 normalized.contains(_normalizeText(e.name)),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Normaliza texto (minúsculas, sin acentos extra)
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
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
        .where((e) => 
            e.key.contains(normalized) || 
            e.value.contains(normalized))
        .toList();
  }
}
