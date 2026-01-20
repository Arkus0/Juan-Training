class LibraryExercise {
  final int id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String? description;
  final String? license;

  LibraryExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.description,
    this.license,
  });

  /// Creates an instance from the locally cached JSON structure.
  factory LibraryExercise.fromJson(Map<String, dynamic> json) {
    return LibraryExercise(
      id: json['id'] as int,
      name: json['name'] as String,
      muscleGroup: json['muscleGroup'] as String? ?? 'Otro',
      equipment: json['equipment'] as String? ?? 'Ninguno',
      description: json['description'] as String?,
      license: json['license'] as String?,
    );
  }

  /// Creates an instance from the Wger API response + resolved names.
  factory LibraryExercise.fromApi(Map<String, dynamic> json, String muscleName, String equipmentName) {
    // Wger API 'description' can be HTML. We keep it as is or strip it.
    // Ideally we strip tags, but for now we just store it.
    return LibraryExercise(
      id: json['id'] as int,
      name: json['name'] as String,
      muscleGroup: muscleName,
      equipment: equipmentName,
      description: json['description'] as String?,
      license: json['license_author'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'equipment': equipment,
      'description': description,
      'license': license,
    };
  }
}
