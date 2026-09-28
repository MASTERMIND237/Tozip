import 'dart:io';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;

class GallerySaver {
  /// Demande la permission puis sauvegarde un fichier dans la galerie.
  /// Retourne true si la sauvegarde a réussi.
  static Future<bool> saveToGallery(String filePath) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) return false;
      }

      final ext = p.extension(filePath).toLowerCase();
      final isVideo = ['.mp4', '.mov', '.mkv', '.avi', '.webm'].contains(ext);

      if (isVideo) {
        await Gal.putVideo(filePath);
      } else {
        await Gal.putImage(filePath);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
