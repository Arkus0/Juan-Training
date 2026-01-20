import 'package:hive/hive.dart';

part 'library_exercise.g.dart';

@HiveType(typeId: 6)
class LibraryExercise extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String muscleGroup; // Category

  @HiveField(3)
  final String equipment;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final String? license;

  @HiveField(6)
  final List<String> imageUrls;

  @HiveField(7)
  String? localImagePath;

  @HiveField(8)
  final List<String> muscles; // Detailed muscles

  @HiveField(9)
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
    // Also check 'images' key might be just urls or objects depending on endpoint.
    // Wger /exercise endpoint usually doesn't include images inline unless we use a specific serializer or fetch separately.
    // But assuming the service handles fetching images or the endpoint provides them.
    // If we fetch images from a separate endpoint, we might merge them later.
    // For now, we assume the input json *might* have them or we set them empty.

    return LibraryExercise(
      id: json['id'] as int,
      name: json['name'] as String,
      muscleGroup: muscleName,
      equipment: equipmentName,
      description: json['description'] as String?,
      license: json['license_author'] as String?,
      imageUrls: images,
      muscles: detailedMuscles,
      secondaryMuscles: detailedSecondaryMuscles,
    );
  }
}
