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
  });

  factory LibraryExercise.fromApi(
    Map<String, dynamic> json,
    String muscleName,
    String equipmentName,
    List<String> detailedMuscles,
    List<String> detailedSecondaryMuscles,
  ) {
    // Extract images
    List<String> images = [];
    if (json['images'] != null) {
      for (var img in json['images']) {
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
    };
  }

  factory LibraryExercise.fromJson(Map<String, dynamic> json) {
    // Helper to normalize lists that may contain strings or maps
    List<String> _normalizeStringList(dynamic val, {String? defaultKey}) {
      if (val == null) return [];
      if (val is List) {
        return val.map((e) {
          if (e == null) return '';
          if (e is String) return e;
          if (e is Map) {
            if (e['name'] != null) return e['name'].toString();
            if (e['name_en'] != null) return e['name_en'].toString();
            if (defaultKey != null && e[defaultKey] != null) return e[defaultKey].toString();
            // Fallback: try to find any string value inside the map
            for (final v in e.values) {
              if (v is String) return v;
            }
            return '';
          }
          return e.toString();
        }).where((s) => s.isNotEmpty).toList();
      }
      return [];
    }

    final int id = json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0;
    final name = (json['name'] as String?) ?? json['name']?.toString() ?? '';

    return LibraryExercise(
      id: id,
      name: name,
      muscleGroup: json['muscleGroup'] as String? ?? '',
      equipment: json['equipment'] as String? ?? '',
      description: json['description'] as String?,
      license: json['license'] as String?,
      imageUrls: (json['imageUrls'] is List)
          ? (json['imageUrls'] as List).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
          : [],
      localImagePath: json['localImagePath'] as String?,
      muscles: _normalizeStringList(json['muscles'], defaultKey: 'name'),
      secondaryMuscles: _normalizeStringList(json['secondaryMuscles'], defaultKey: 'name'),
    );
  }
}
