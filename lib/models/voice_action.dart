/// lib/models/voice_action.dart
/// Modelo para acciones detectadas por voz.

/// Tipos de acciones que puede reconocer el sistema de voz.
enum VoiceActionType {
  setWeight,
  setReps,
  setRpe,
  addNote,
  markDone,
  nextSet,
  addExercise,
  removeExercise,
}

/// Representa una acción detectada por voz.
class VoiceAction {
  final VoiceActionType type;
  final String description;
  final Map<String, dynamic>? payload; // Opcional para datos adicionales

  const VoiceAction({
    required this.type,
    required this.description,
    this.payload,
  });

  @override
  String toString() => 'VoiceAction($type, $description)';
}