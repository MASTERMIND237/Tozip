import 'dart:io';

enum MediaType { image, video }

/// Représente un fichier média avec son état de compression.
class MediaItem {
  final String originalPath;
  final MediaType type;

  String? compressedPath;
  int? originalSize;
  int? compressedSize;
  bool isProcessing = false;
  bool isDone = false;
  String? error;
/// ID dans la galerie Android (résolu après compression/sauvegarde)
  String? assetId;
/// Indique si le fichier a été sauvegardé avec succès dans la galerie
  bool savedToGallery = false;

  MediaItem({
    required this.originalPath,
    required this.type,
  });

  String get fileName => originalPath.split('/').last;

  int get savedBytes => (originalSize ?? 0) - (compressedSize ?? 0);

  double get savedPercentage {
    if (originalSize == null || compressedSize == null || originalSize == 0) {
      return 0;
    }
    return (savedBytes / originalSize!) * 100;
  }
}