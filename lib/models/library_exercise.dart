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
    return LibraryExercise(
      id: json['id'] as int,
      name: json['name'] as String,
      muscleGroup: json['muscleGroup'] as String,
      equipment: json['equipment'] as String,
      description: json['description'] as String?,
      license: json['license'] as String?,
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      localImagePath: json['localImagePath'] as String?,
      muscles: (json['muscles'] as List<dynamic>?)?.cast<String>() ?? [],
      secondaryMuscles: (json['secondaryMuscles'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}
