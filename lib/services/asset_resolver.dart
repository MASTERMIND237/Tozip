import 'package:photo_manager/photo_manager.dart';

class AssetResolver {
  /// Résout plusieurs chemins de fichiers en une seule passe dans les albums.
  /// Retourne une Map { cheminOriginal -> assetId }.
  static Future<Map<String, String>> resolveMultiple(
    List<String> filePaths,
  ) async {
    final result = <String, String>{};
    final fileNameToPath = <String, String>{};

    for (final path in filePaths) {
      fileNameToPath[path.split('/').last] = path;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: false,
    );

    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;

      int page = 0;
      const pageSize = 300;

      while (page * pageSize < count) {
        final assets = await album.getAssetListPaged(
          page: page,
          size: pageSize,
        );

        for (final asset in assets) {
          final originalPath = fileNameToPath[asset.title];
          if (originalPath != null && !result.containsKey(originalPath)) {
            result[originalPath] = asset.id;
          }
        }

        if (result.length == filePaths.length) break;
        page++;
      }
    }

    return result;
  }
}