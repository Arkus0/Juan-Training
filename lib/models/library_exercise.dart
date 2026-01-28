class LibraryExercise {
  final int id;
  final String name;
  final String muscleGroup; // Category
  final String equipment;
  final String? description;
  final String? license;
  final List<String> imageUrls;
  String? localImagePath;
  final List<String> muscles; // Detailed muscles
  final List<String> secondaryMuscles;
  bool isFavorite; // User-marked favorite

  /// Flag para ejercicios curados manualmente.
  /// Si es true, la sincronización con API NO puede sobrescribir ni eliminar este ejercicio.
  /// Los ejercicios bundled (assets/data/exercises.json) son curados por defecto.
  /// CRÍTICO: Este flag protege la base de datos curada de ser destruida por syncs automáticas.
  final bool isCurated;

  LibraryExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.description,
    this.license,
    this.imageUrls = const [],
    this.localImagePath,
    this.muscles = const [],
    this.secondaryMuscles = const [],
    this.isFavorite = false,
    this.isCurated = false,
  });

  factory LibraryExercise.fromApi(
    Map<String, dynamic> json,
    String muscleName,
    String equipmentName,
    List<String> detailedMuscles,
    List<String> detailedSecondaryMuscles,
  ) {
    // Extract images
    final images = <String>[];
    if (json['images'] != null) {
      for (final img in json['images']) {
        if (img['image'] != null) {
          images.add(img['image']);
        }
      }
    }

    final id = json['id'];
    if (id == null || id is! int) {
      throw Exception('Invalid or missing ID from API for item: $json');
    }

    return LibraryExercise(
      id: id,
      name: json['name']?.toString() ?? '',
      muscleGroup: muscleName,
      equipment: equipmentName,
      description: json['description'] as String?,
      license: json['license_author'] as String?,
      imageUrls: images,
      muscles: detailedMuscles,
      secondaryMuscles: detailedSecondaryMuscles,
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
      'imageUrls': imageUrls,
      'localImagePath': localImagePath,
      'muscles': muscles,
      'secondaryMuscles': secondaryMuscles,
      'isFavorite': isFavorite,
      'isCurated': isCurated,
    };
  }

  factory LibraryExercise.fromJson(Map<String, dynamic> json) {
    // Helper to normalize lists that may contain strings or maps
    List<String> normalizeStringList(dynamic val, {String? defaultKey}) {
      if (val == null) return [];
      if (val is List) {
        return val
            .map((e) {
              if (e == null) return '';
              if (e is String) return e;
              if (e is Map) {
                if (e['name'] != null) return e['name'].toString();
                if (e['name_en'] != null) return e['name_en'].toString();
                if (defaultKey != null && e[defaultKey] != null) {
                  return e[defaultKey].toString();
                }
                // Fallback: try to find any string value inside the map
                for (final v in e.values) {
                  if (v is String) return v;
                }
                return '';
              }
              return e.toString();
            })
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    }

    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '') ?? 0;
    final name = (json['name'] as String?) ?? json['name']?.toString() ?? '';

    return LibraryExercise(
      id: id,
      name: name,
      muscleGroup: json['muscleGroup'] as String? ?? '',
      equipment: json['equipment'] as String? ?? '',
      description: json['description'] as String?,
      license: json['license'] as String?,
      imageUrls: (json['imageUrls'] is List)
          ? (json['imageUrls'] as List)
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
          : [],
      localImagePath: json['localImagePath'] as String?,
      muscles: normalizeStringList(json['muscles'], defaultKey: 'name'),
      secondaryMuscles:
          normalizeStringList(json['secondaryMuscles'], defaultKey: 'name'),
      isFavorite: json['isFavorite'] as bool? ?? false,
      // CRÍTICO: Ejercicios del JSON bundled son curados por defecto (true).
      // Solo son false si explícitamente vienen de la API y se marca como tal.
      isCurated: json['isCurated'] as bool? ?? true,
    );
  }

  /// Creates a copy with updated fields
  LibraryExercise copyWith({
    int? id,
    String? name,
    String? muscleGroup,
    String? equipment,
    String? description,
    String? license,
    List<String>? imageUrls,
    String? localImagePath,
    List<String>? muscles,
    List<String>? secondaryMuscles,
    bool? isFavorite,
    bool? isCurated,
  }) {
    return LibraryExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      description: description ?? this.description,
      license: license ?? this.license,
      imageUrls: imageUrls ?? this.imageUrls,
      localImagePath: localImagePath ?? this.localImagePath,
      muscles: muscles ?? this.muscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      isFavorite: isFavorite ?? this.isFavorite,
      isCurated: isCurated ?? this.isCurated,
    );
  }
}
