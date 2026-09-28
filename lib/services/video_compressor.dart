import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class CompressionResult {
  final String originalPath;
  final String compressedPath;
  final int originalSize;
  final int compressedSize;
  
  CompressionResult({
    required this.originalPath,
    required this.compressedPath,
    required this.originalSize,
    required this.compressedSize,
  });
  
  double get savedBytes => (originalSize - compressedSize).toDouble();
  double get savedPercentage => 
      ((originalSize - compressedSize) / originalSize * 100);
}

class VideoCompressor {
  /// Compresse une vidéo avec FFmpeg.
  /// [crf] : 23 par défaut (bon compromis qualité/taille). 18-28 recommandé.
  /// [preset] : "medium" par défaut. "fast" pour aller plus vite.
  static Future<CompressionResult> compress({
    required String inputPath,
    int crf = 23,
    String preset = 'medium',
    Function(double)? onProgress,
  }) async {
    final inputFile = File(inputPath);
    final originalSize = await inputFile.length();
    
    // Dossier de sortie dans le cache de l'app
    final cacheDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${cacheDir.path}/compressed_$timestamp.mp4';
    
    // Commande FFmpeg pour compression H.264 + AAC
    final command = '-y -i "$inputPath" '
        '-c:v libx264 '
        '-crf $crf '
        '-preset $preset '
        '-c:a aac -b:a 128k '
        '-movflags +faststart '
        '"$outputPath"';
    
    // Exécution asynchrone pour ne pas bloquer l'UI
    final session = await FFmpegKit.executeAsync(
      command,
      (session) async {},
      (log) {},
      (statistics) {
        // FFmpeg n'expose pas toujours un progress fiable sur les vidéos courtes
        // On peut calculer via la durée si nécessaire
      },
    );
    
    final returnCode = await session.getReturnCode();
    
    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      throw Exception('Échec de compression FFmpeg: $output');
    }
    
    final compressedFile = File(outputPath);
    if (!await compressedFile.exists()) {
      throw Exception('Fichier de sortie non créé: $outputPath');
    }
    
    final compressedSize = await compressedFile.length();
    
    return CompressionResult(
      originalPath: inputPath,
      compressedPath: outputPath,
      originalSize: originalSize,
      compressedSize: compressedSize,
    );
  }
  
  /// Formate une taille en bytes vers un texte lisible
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }
}