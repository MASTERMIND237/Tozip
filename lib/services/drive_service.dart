import 'package:multi_cloud_storage/multi_cloud_storage.dart';
import 'package:multi_cloud_storage/cloud_storage_provider.dart';

/// Service simplifié pour interagir avec Google Drive via multi_cloud_storage.
///
/// L'API de ce package fonctionne par provider : on appelle
/// MultiCloudStorage.connectToGoogleDrive() qui retourne une instance
/// de CloudStorageProvider sur laquelle on effectue les opérations.
class DriveService {
  /// Instance partagée du provider Google Drive.
  /// Reste null tant que l'utilisateur ne s'est pas connecté.
  static CloudStorageProvider? _googleDrive;

  /// Vérifie si l'utilisateur est connecté à Google Drive.
  static Future<bool> isConnected() async {
    if (_googleDrive != null) return true;
    try {
      _googleDrive = await MultiCloudStorage.connectToGoogleDrive();
      return _googleDrive != null;
    } catch (_) {
      return false;
    }
  }

  /// Connecte l'utilisateur à Google Drive.
  /// Ouvre une page de login Google si nécessaire.
  /// Retourne true si la connexion a réussi.
  static Future<bool> connect() async {
    try {
      _googleDrive = await MultiCloudStorage.connectToGoogleDrive();
      return _googleDrive != null;
    } catch (_) {
      return false;
    }
  }

  /// Déconnecte l'utilisateur.
  static Future<void> disconnect() async {
    _googleDrive = null;
  }

  /// Upload un fichier local vers l'App Folder de Google Drive.
  /// [remoteName] : nom du fichier tel qu'il apparaîtra sur Drive.
  /// Retourne true si l'upload a réussi.
  static Future<bool> uploadFile({
    required String localPath,
    String? remoteName,
  }) async {
    try {
      final drive = _googleDrive ??
          await MultiCloudStorage.connectToGoogleDrive();
      if (drive == null) return false;
      _googleDrive = drive;

      final fileName = remoteName ?? localPath.split('/').last;

      await drive.uploadFile(
        localPath: localPath,
        remotePath: fileName,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Liste les fichiers présents dans l'App Folder de Drive.
  static Future<List<CloudFile>> listFiles() async {
    try {
      final drive = _googleDrive ??
          await MultiCloudStorage.connectToGoogleDrive();
      if (drive == null) return [];
      _googleDrive = drive;
      return await drive.listFiles(path: '/');
    } catch (_) {
      return [];
    }
  }

  /// Supprime un fichier distant par son nom.
  static Future<bool> deleteFile(String remoteName) async {
    try {
      final drive = _googleDrive ??
          await MultiCloudStorage.connectToGoogleDrive();
      if (drive == null) return false;
      _googleDrive = drive;
      await drive.deleteFile(remoteName);
      return true;
    } catch (_) {
      return false;
    }
  }
}