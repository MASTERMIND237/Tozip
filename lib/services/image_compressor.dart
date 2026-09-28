import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressionResult {
  final String originalPath;
  final String compressedPath;
  final int originalSize;
  final int compressedSize;

  ImageCompressionResult({
    required this.originalPath,
    required this.compressedPath,
    required this.originalSize,
    required this.compressedSize,
  });

  int get savedBytes => originalSize - compressedSize;
  double get savedPercentage =>
      ((originalSize - compressedSize) / originalSize * 100);
}

class ImageCompressor {
  /// Compresse une image en JPEG avec une qualité visuellement équivalente.
  ///
  /// [quality] : 85 par défaut. C'est le "sweet spot" — au-dessus de 90, le
  /// gain de taille devient négligeable ; en dessous de 75, les artefacts
  /// deviennent visibles sur les visages et les ciels dégradés.
  ///
  /// [maxWidth] / [maxHeight] : limitent la résolution pour éviter de garder
  /// des photos 48MP inutiles sur un écran de téléphone.
  static Future<ImageCompressionResult> compress({
    required String inputPath,
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    final inputFile = File(inputPath);
    final originalSize = await inputFile.length();

    final cacheDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${cacheDir.path}/compressed_$timestamp.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      inputPath,
      outputPath,
      quality: quality,
      minWidth: maxWidth,
      minHeight: maxHeight,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      throw Exception('Échec de compression de l\'image');
    }

    final compressedFile = File(result.path);
    final compressedSize = await compressedFile.length();

    return ImageCompressionResult(
      originalPath: inputPath,
      compressedPath: result.path,
      originalSize: originalSize,
      compressedSize: compressedSize,
    );
  }

  /// Formate une taille en bytes vers un texte lisible
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }
}