// Script para podar ejercicios a los esenciales
// Ejecutar con: dart run bin/prune_exercises.dart

import 'dart:convert';
import 'dart:io';

/// IDs de ejercicios esenciales a mantener.
/// Criterio: ejercicios que el 80% de usuarios intermedios-avanzados conocen y usan.
///
/// FILOSOFÍA:
/// - Un ejercicio por patrón de movimiento por equipo
/// - No variantes "exóticas" (landmine, 21s, isométricos raros)
/// - Si el usuario quiere algo específico, que lo cree manualmente

const List<int> essentialExerciseIds = [
  // ===== PIERNAS (25 ejercicios) =====
  615, // Sentadillas (bodyweight)
  1627, // Barbell squat
  257, // Sentadilla Frontal
  1747, // Sentadilla multipower
  1414, // Sentadillas Hack
  371, // Prensa de piernas
  851, // Extensión de cuádriceps
  364, // Curl femoral (lying)
  366, // Curl femoral sentado
  205, // Zancadas con Mancuernas
  46, // Zancadas con Barra
  706, // Sentadilla búlgara (usar 1706 si existe)
  1706, // Bulgarian Squat with Dumbbells
  184, // Peso Muerto Convencional
  507, // Peso muerto rumano con barra
  630, // Sumo Deadlift
  1652, // Dumbbell Romanian Deadlift
  294, // Barbell Hip Thrust
  1642, // Dumbbell Hip Thrust
  265, // Glute Bridge
  1748, // Abducción en máquina
  12, // Aducción de Cadera en Máquina
  268, // Good Mornings
  981, // Subida a peldaño
  1243, // Double Leg Calf Raise

  // ===== PECHO (18 ejercicios) =====
  73, // Press de Banca
  75, // Press de banca con mancuernas
  538, // Press de banca inclinado
  1277, // Press inclinado con mancuernas
  185, // Press de Banca Declinado con Barra
  186, // Press de Banca Declinado con Mancuernas
  76, // Press de Banca con Agarre Cerrado
  129, // Press de Pecho en Máquina
  238, // Aperturas con Mancuernas
  308, // Incline Dumbbell Fly
  237, // Cruce de Poleas para Pecho
  135, // Aperturas en máquina
  194, // Fondos en Paralelas
  1551, // Push-Up
  188, // Flexiones Declinadas
  313, // Incline Push up
  161, // Pullover con Mancuerna
  1674, // Dumbbell Floor Press

  // ===== ESPALDA (22 ejercicios) =====
  475, // Dominadas
  152, // Dominadas con Agarre Supino
  1806, // Lat Pull Down
  723, // Wide-grip Pulldown
  158, // Jalón al Pecho con Agarre Cerrado
  684, // Underhand Lat Pull Down
  81, // Remo con mancuernas
  83, // Remo Inclinado con Barra (agarre prono)
  394, // Remo con polea
  1725, // Seated Row (Machine)
  508, // Remo maquina abierto
  513, // Remo en "T"
  919, // T-Bar row
  1303, // Helms Row
  629, // Straight-arm Pull Down (rope)
  301, // Hyperextensions
  636, // Superman
  828, // Aperturas Inversas (Face Pull alternativo)
  222, // Jalón a la Cara (Face Pulls)
  184, // Peso Muerto Convencional (ya incluido en piernas)
  484, // Rack Deadlift
  571, // Shrugs, Barbells

  // ===== HOMBROS (16 ejercicios) =====
  418, // Press militar
  567, // Press Militar mancuerna
  478, // Press de hombro con mancuernas
  20, // Press Arnold
  543, // Press de hombro con maquina
  348, // Elevación lateral con mancuernas
  1744, // Elevación lateral en maquina
  1378, // Cable Lateral Raises
  256, // Elevaciones frontales
  254, // Elevaciones Frontales con Disco
  82, // Elevaciones Posteriores (Rear Delt Raises)
  139, // Pec-Deck Inverso
  572, // Shrugs, Dumbbells
  693, // Remo al Mentón
  282, // Handstand Pushup
  578, // Side-lying External Rotation

  // ===== BRAZOS - BÍCEPS (12 ejercicios) =====
  91, // Curl con barra
  94, // Curl de biceps con barra Z
  92, // Curl de bíceps con mancuerna
  204, // Curl Inclinado con Mancuernas
  272, // Curl Martillo
  95, // Curl de Bíceps en Polea
  465, // Preacher Curls
  202, // Dumbbell Concentration Curl
  1289, // Curl con mancuernas sentado
  1012, // Curl de biceps alterno
  1465, // Curl Araña
  1493, // Bayesian Curl

  // ===== BRAZOS - TRÍCEPS (12 ejercicios) =====
  659, // Extension de triceps polea
  1185, // Extensión de tríceps en polea con cuerda
  655, // Contragolpe de tríceps con mancuernas
  50, // Extensión de triceps (skull crusher)
  246, // Press Francés con Barra SZ
  211, // Press Francés con Mancuerna
  803, // Extensión de Tríceps a una Mano en Polea
  1519, // Overhead Triceps Extension
  197, // Fondos entre Bancos
  661, // Triceps on Machine
  1000, // Fondos
  1749, // Fondos en maquina

  // ===== ABDOMINALES (15 ejercicios) =====
  167, // Abdominales (Crunches)
  458, // Plancha de antebrazo
  580, // Plancha de lado izquierdo
  1019, // Plancha de lado derecho
  283, // Elevaciones de Piernas (Colgado)
  377, // Leg Raises, Lying
  178, // Bicho Muerto
  1772, // Reverse crunch
  1412, // Abdominales en bicicleta
  1089, // Abdominales rusas
  1411, // Toques de Talón
  145, // Leñadores en Polea
  1573, // Ab wheel
  172, // Abdominales en Máquina
  297, // Hollow Hold

  // ===== CARDIO (8 ejercicios) =====
  132, // Burpees
  320, // Polichinelas (Jumping Jacks)
  996, // Montañeros
  614, // Squat Jumps
  331, // Kettlebell Swings
  650, // Thruster
  675, // Turkish Get-Up
  616, // Squat Thrust

  // ===== PANTORRILLAS (4 ejercicios) =====
  1243, // Double Leg Calf Raise (ya incluido)
  1365, // Calf Raise with machine (seated)
  1494, // Sitting Calf Raises
  1466, // Calf Raise using Hack Squat Machine

  // ===== ADICIONALES ÚTILES =====
  910, // Curl Nórdico
  386, // Diamond push ups
  1104, // Walking (cardio)
  174, // Encogimientos con Piernas Elevadas
  571, // Shrugs Barbells (ya está)
];

void main() async {
  final inputFile = File('assets/data/exercises.json');
  final backupFile = File('assets/data/exercises_full_backup.json');
  final outputFile = File('assets/data/exercises_pruned.json');

  if (!await inputFile.exists()) {
    stdout.writeln('❌ No se encontró assets/data/exercises.json');
    exit(1);
  }

  // Leer ejercicios actuales
  final content = await inputFile.readAsString();
  final List<dynamic> allExercises = jsonDecode(content);

  stdout.writeln('📊 Ejercicios originales: ${allExercises.length}');

  // Crear backup
  await backupFile.writeAsString(content);
  stdout.writeln('💾 Backup creado en: ${backupFile.path}');

  // Crear set de IDs para búsqueda rápida
  final essentialIds = essentialExerciseIds.toSet();

  // Filtrar ejercicios
  final prunedExercises = allExercises.where((ex) {
    return essentialIds.contains(ex['id'] as int);
  }).toList();

  stdout.writeln('✂️ Ejercicios después de podar: ${prunedExercises.length}');

  // Encontrar IDs que no existen
  final foundIds = prunedExercises.map((e) => e['id'] as int).toSet();
  final missingIds = essentialIds.difference(foundIds);
  if (missingIds.isNotEmpty) {
    stdout.writeln('⚠️ IDs no encontrados: $missingIds');
  }

  // Ordenar por grupo muscular y nombre
  prunedExercises.sort((a, b) {
    final groupCompare =
        (a['muscleGroup'] as String).compareTo(b['muscleGroup'] as String);
    if (groupCompare != 0) return groupCompare;
    return (a['name'] as String).compareTo(b['name'] as String);
  });

  // Guardar archivo podado
  const encoder = JsonEncoder.withIndent('  ');
  await outputFile.writeAsString(encoder.convert(prunedExercises));
  stdout.writeln('✅ Guardado en: ${outputFile.path}');

  // Estadísticas por grupo
  stdout.writeln('\n📈 Distribución final:');
  final byGroup = <String, int>{};
  for (final ex in prunedExercises) {
    final group = ex['muscleGroup'] as String;
    byGroup[group] = (byGroup[group] ?? 0) + 1;
  }
  byGroup.forEach((group, count) {
    stdout.writeln('   $group: $count');
  });

  // === ACTUALIZAR ALTERNATIVAS ===
  final alternativasFile = File('assets/data/alternativas.json');
  if (await alternativasFile.exists()) {
    final altContent = await alternativasFile.readAsString();
    final Map<String, dynamic> alternativas = jsonDecode(altContent);

    // Backup de alternativas
    await File('assets/data/alternativas_backup.json')
        .writeAsString(altContent);

    // Filtrar alternativas: solo mantener ejercicios que existen en la lista podada
    final prunedAlternativas = <String, dynamic>{};
    var removedKeys = 0;
    var removedValues = 0;

    for (final entry in alternativas.entries) {
      final keyId = int.tryParse(entry.key);
      if (keyId == null || !foundIds.contains(keyId)) {
        removedKeys++;
        continue; // Eliminar alternativas de ejercicios que no existen
      }

      // Filtrar alternativas que ya no existen
      final originalAlts = entry.value as List<dynamic>;
      final filteredAlts =
          originalAlts.where((altId) => foundIds.contains(altId)).toList();
      removedValues += originalAlts.length - filteredAlts.length;

      if (filteredAlts.isNotEmpty) {
        prunedAlternativas[entry.key] = filteredAlts;
      }
    }

    // Guardar alternativas podadas
    const altEncoder = JsonEncoder.withIndent(null); // Compacto
    await File('assets/data/alternativas_pruned.json')
        .writeAsString(altEncoder.convert(prunedAlternativas));

    stdout.writeln('\n📋 Alternativas:');
    stdout.writeln('   Claves originales: ${alternativas.length}');
    stdout.writeln('   Claves después de podar: ${prunedAlternativas.length}');
    stdout.writeln('   Claves eliminadas: $removedKeys');
    stdout.writeln('   Referencias eliminadas: $removedValues');
  }

  stdout.writeln('\n🎯 Para aplicar los cambios:');
  stdout.writeln('   1. Revisar assets/data/exercises_pruned.json');
  stdout.writeln('   2. Revisar assets/data/alternativas_pruned.json');
  stdout.writeln('   3. Si está bien, ejecutar:');
  stdout.writeln(
      '      copy assets\\data\\exercises_pruned.json assets\\data\\exercises.json',);
  stdout.writeln(
      '      copy assets\\data\\alternativas_pruned.json assets\\data\\alternativas.json',);
}
