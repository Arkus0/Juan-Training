import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:logger/logger.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/services/exercise_library_service.dart';

class ParsedExerciseCandidate {
  final String originalText;
  final LibraryExercise? matchedExercise;
  final int series;
  final String reps;
  final String? weight; // e.g. "OCR Ref: 80kg"

  ParsedExerciseCandidate({
    required this.originalText,
    this.matchedExercise,
    this.series = 3,
    this.reps = '8-12',
    this.weight,
  });
}

class RoutineOcrService {
  static final RoutineOcrService instance = RoutineOcrService._();
  RoutineOcrService._();

  final _logger = Logger();
  final _picker = ImagePicker();

  /// Picks an image from source, scans text, and returns raw lines.
  Future<List<String>> pickAndScanImage(ImageSource source) async {
    final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return [];

      final inputImage = InputImage.fromFilePath(image.path);

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // Split into lines and filter empty/short
      final lines = recognizedText.blocks
          .expand((block) => block.lines)
          .map((line) => line.text)
          .where((text) => text.trim().length > 2) // Filter very short noise
          .toList();

      return lines;
    } catch (e, s) {
      _logger.e('Error scanning image', error: e, stackTrace: s);
      // Return empty list on error to handle gracefully in UI
      return [];
    } finally {
      await _textRecognizer.close();
    }
  }

  /// Parses raw lines into candidate exercises using Regex and Fuzzy Search.
  Future<List<ParsedExerciseCandidate>> parseLines(List<String> lines) async {
    final library = ExerciseLibraryService.instance.exercises;
    // Map names to exercises for easy lookup after fuzzy match
    final nameToExercise = {for (var e in library) e.name: e};
    final exerciseNames = library.map((e) => e.name).toList();

    // Configure Fuzzy search
    final fuse = Fuzzy(
      exerciseNames,
      options: FuzzyOptions(
        threshold: 0.4, // 0.0=Perfect, 1.0=Any. 0.4 allows for minor typos/variations.
      ),
    );

    final List<ParsedExerciseCandidate> results = [];

    for (String line in lines) {
      // 1. Parse Metrics (Series, Reps, Weight) using Regex
      int? series;
      String? reps;
      String? weight;

      String cleanedLine = line;

      // Regex 1: NxN (e.g. 4x10, 4 x 10)
      // Captures: Group 1 (Series), Group 2 (Reps)
      final nxnRegex = RegExp(r'(\d+)\s*[xX]\s*(\d+)');
      final nxnMatch = nxnRegex.firstMatch(cleanedLine);
      if (nxnMatch != null) {
        series = int.tryParse(nxnMatch.group(1)!);
        reps = nxnMatch.group(2);
        // Remove match from string
        cleanedLine = cleanedLine.replaceFirst(nxnMatch.group(0)!, '');
      }

      // Regex 2: Explicit "Series" / "Reps" keywords
      // Only if not found by NxN
      if (series == null) {
        final seriesRegex = RegExp(r'(\d+)\s*(?:series|sets|s(?=\s|$))', caseSensitive: false);
        final seriesMatch = seriesRegex.firstMatch(cleanedLine);
        if (seriesMatch != null) {
          series = int.tryParse(seriesMatch.group(1)!);
          cleanedLine = cleanedLine.replaceFirst(seriesMatch.group(0)!, '');
        }
      }
      if (reps == null) {
        final repsRegex = RegExp(r'(\d+)\s*(?:reps|repeticiones|r(?=\s|$))', caseSensitive: false);
        final repsMatch = repsRegex.firstMatch(cleanedLine);
        if (repsMatch != null) {
          reps = repsMatch.group(1);
          cleanedLine = cleanedLine.replaceFirst(repsMatch.group(0)!, '');
        }
      }

      // Regex 3: Weight with units (kg, lb)
      final weightRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:kg|lb|kgs|lbs)', caseSensitive: false);
      final weightMatch = weightRegex.firstMatch(cleanedLine);
      if (weightMatch != null) {
        weight = 'OCR Ref: ${weightMatch.group(0)}';
        cleanedLine = cleanedLine.replaceFirst(weightMatch.group(0)!, '');
      } else {
        // Fallback: Number at end of string if we already found series/reps
        // This handles "Press 4x10 80" -> 80kg
        if (series != null || reps != null) {
             final looseNumberRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*$');
             final looseMatch = looseNumberRegex.firstMatch(cleanedLine);
             if (looseMatch != null) {
                 weight = 'OCR Ref: ${looseMatch.group(1)}kg';
                 cleanedLine = cleanedLine.replaceFirst(looseMatch.group(0)!, '');
             }
        }
      }

      // 2. Fuzzy Match Name
      // Clean up punctuation and numbers that might remain
      String nameQuery = cleanedLine.replaceAll(RegExp(r'[^\w\sñÑáéíóúÁÉÍÓÚ]'), ' ').trim();
      // Collapse multiple spaces
      nameQuery = nameQuery.replaceAll(RegExp(r'\s+'), ' ');

      if (nameQuery.length < 3) continue; // Skip too short lines

      LibraryExercise? matched;
      final searchResults = fuse.search(nameQuery);
      if (searchResults.isNotEmpty) {
        final bestMatch = searchResults.first;
        // Check threshold explicitly if needed, though Fuse options handle it.
        // We accept the best match provided by Fuse within threshold.
        matched = nameToExercise[bestMatch.item];
      }

      // 3. Add to results
      results.add(ParsedExerciseCandidate(
        originalText: line,
        matchedExercise: matched,
        series: series ?? 3, // Default
        reps: reps ?? '8-12', // Default
        weight: weight,
      ));
    }

    return results;
  }
}
