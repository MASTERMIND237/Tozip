import 'package:photo_manager/photo_manager.dart';

class GalleryDeleter {
  /// Demande la permission d'accéder aux médias (images + vidéos).
  static Future<bool> requestPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    return permission.isAuth || permission.hasAccess;
  }

  /// Supprime une liste d'assets par leurs IDs.
  /// Le système Android affichera UNE SEULE boîte de confirmation
  /// pour tout le lot (Android 11+).
  /// Retourne la liste des IDs effectivement supprimés.
  static Future<List<String>> deleteByIds(List<String> assetIds) async {
    if (assetIds.isEmpty) return [];

    try {
      final deletedIds = await PhotoManager.editor.deleteWithIds(assetIds);
      return deletedIds;
    } catch (e) {
      return [];
    }
  }
}