/// Representa una acción realizada vía voz que puede deshacerse.
class VoiceAction {
  final VoiceActionType type;
  final String description;

  const VoiceAction({required this.type, required this.description});
}

/// Tipos de acciones por voz (coinciden con iconos usados en UI)
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
