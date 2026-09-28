import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/media_item.dart';
import '../services/asset_resolver.dart';
import '../services/batch_compressor.dart';
import '../services/drive_service.dart';
import '../services/gallery_deleter.dart';
import '../services/gallery_saver.dart';
import '../theme/app_theme.dart';

class BatchScreen extends StatefulWidget {
  final MediaType mediaType;

  const BatchScreen({super.key, required this.mediaType});

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  List<MediaItem> _items = [];
  bool _isCompressing = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isUploading = false;
  int _currentIndex = 0;
  int _totalCount = 0;
  MediaItem? _currentItem;

  int get _maxCount => widget.mediaType == MediaType.video ? 5 : 20;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: widget.mediaType == MediaType.video
          ? FileType.video
          : FileType.image,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files
        .where((f) => f.path != null)
        .take(_maxCount)
        .map((f) => MediaItem(
              originalPath: f.path!,
              type: widget.mediaType,
            ))
        .toList();

    if (picked.length < result.files.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum $_maxCount fichiers. ${result.files.length - picked.length} ignorés.',
          ),
        ),
      );
    }

    setState(() {
      _items = picked;
    });
  }

  Future<void> _startCompression() async {
    if (_items.isEmpty) return;

    setState(() {
      _isCompressing = true;
      _currentIndex = 0;
      _totalCount = _items.length;
      _currentItem = null;
    });

    await BatchCompressor.compressAll(
      _items,
      onProgress: (progress) {
        setState(() {
          _currentIndex = progress.current;
          _currentItem = progress.item;
        });
      },
      onItemDone: (_) {},
      onComplete: () {
        setState(() {
          _isCompressing = false;
          _currentItem = null;
        });
      },
    );
  }

  Future<void> _saveAllToGallery() async {
    setState(() => _isSaving = true);

    int saved = 0;
    int failed = 0;

    for (final item in _items) {
      if (item.compressedPath != null && item.isDone) {
        final ok = await GallerySaver.saveToGallery(item.compressedPath!);
        if (ok) {
          item.savedToGallery = true;
          saved++;
        } else {
          item.savedToGallery = false;
          failed++;
        }
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '$saved fichier(s) sauvegardé(s) dans la galerie'
              : '$saved sauvegardé(s), $failed échec(s)',
        ),
      ),
    );
  }

  Future<void> _uploadAllToDrive() async {
    final itemsToUpload = _items
        .where((item) => item.compressedPath != null && item.isDone)
        .toList();

    if (itemsToUpload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun fichier compressé à envoyer.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    // Vérifier la connexion Drive, sinon tenter de se connecter
    final connected = await DriveService.isConnected();
    if (!connected) {
      final ok = await DriveService.connect();
      if (!ok) {
        if (!mounted) return;
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion à Google Drive refusée.')),
        );
        return;
      }
    }

    int success = 0;
    int failed = 0;

    for (final item in itemsToUpload) {
      final ok = await DriveService.uploadFile(
        localPath: item.compressedPath!,
        remoteName: item.fileName,
      );
      if (ok) {
        success++;
      } else {
        failed++;
      }
    }

    if (!mounted) return;
    setState(() => _isUploading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '$success fichier(s) envoyé(s) sur Drive'
              : '$success envoyé(s), $failed échec(s)',
        ),
      ),
    );
  }

  Future<void> _deleteOriginals() async {
    final itemsToDelete = _items
        .where((item) => item.savedToGallery && item.isDone)
        .toList();

    if (itemsToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun fichier sauvegardé à remplacer.'),
        ),
      );
      return;
    }

    setState(() => _isDeleting = true);

    final hasPermission = await GalleryDeleter.requestPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission refusée pour accéder à la galerie.'),
        ),
      );
      return;
    }

    final paths = itemsToDelete.map((e) => e.originalPath).toList();
    final idMap = await AssetResolver.resolveMultiple(paths);

    final idsToDelete = <String>[];
    for (final item in itemsToDelete) {
      final id = idMap[item.originalPath];
      if (id != null) {
        item.assetId = id;
        idsToDelete.add(id);
      }
    }

    if (idsToDelete.isEmpty) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de retrouver les originaux dans la galerie.'),
        ),
      );
      return;
    }

    final deleted = await GalleryDeleter.deleteByIds(idsToDelete);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${deleted.length} original(aux) supprimé(s). '
          '${idsToDelete.length - deleted.length} échec(s).',
        ),
      ),
    );
  }

  int get _totalOriginalBytes =>
      _items.fold(0, (sum, item) => sum + (item.originalSize ?? 0));

  int get _totalCompressedBytes =>
      _items.fold(0, (sum, item) => sum + (item.compressedSize ?? 0));

  int get _totalSavedBytes => _totalOriginalBytes - _totalCompressedBytes;

  bool get _allDone =>
      _items.isNotEmpty &&
      _items.every((item) => item.isDone || item.error != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mediaType == MediaType.video
            ? 'Compresser des vidéos'
            : 'Compresser des photos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_items.isEmpty)
              Expanded(child: _buildEmptyState())
            else
              Expanded(child: _buildItemList()),
            if (_isCompressing) _buildProgressBar(),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.mediaType == MediaType.video
                ? Icons.video_library
                : Icons.photo_library,
            size: 80,
            color: AppColors.accent,
          ),
          const SizedBox(height: 16),
          Text(
            'Sélectionne jusqu\'à $_maxCount ${widget.mediaType == MediaType.video ? "vidéos" : "photos"}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choisir des fichiers'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildItemTile(_items[index]);
      },
    );
  }

  Widget _buildItemTile(MediaItem item) {
    final isCurrent = _currentItem == item && item.isProcessing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildStatusIcon(item, isCurrent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  if (item.error != null)
                    Text(
                      'Erreur : ${item.error}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    )
                  else if (item.isDone)
                    Text(
                      '${_formatSize(item.originalSize ?? 0)} → '
                      '${_formatSize(item.compressedSize ?? 0)}  '
                      '(-${item.savedPercentage.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        color: item.savedPercentage > 20
                            ? Colors.green.shade700
                            : AppColors.caramel,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    const Text('En attente...',
                        style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            if (item.savedToGallery)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.cloud_done,
                  size: 20,
                  color: Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MediaItem item, bool isCurrent) {
    if (isCurrent) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (item.error != null) {
      return const Icon(Icons.error_outline, color: Colors.red, size: 32);
    }
    if (item.isDone) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 32);
    }
    return const Icon(Icons.schedule, color: AppColors.accentLight, size: 32);
  }

  Widget _buildProgressBar() {
    final fraction = _totalCount == 0 ? 0.0 : _currentIndex / _totalCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: fraction,
            color: AppColors.accent,
            backgroundColor: AppColors.surface,
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            'Fichier $_currentIndex sur $_totalCount',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_items.isEmpty) return const SizedBox.shrink();

    if (_isCompressing) {
      return const SizedBox.shrink();
    }

    if (_allDone) {
      final savedCount = _items.where((i) => i.savedToGallery).length;
      final canDelete = savedCount > 0;
      final compressedCount =
          _items.where((i) => i.isDone && i.error == null).length;
      final canUpload = compressedCount > 0;

      return Column(
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveAllToGallery,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(_isSaving ? 'Sauvegarde...' : 'Sauver'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.caramel,
                    side: const BorderSide(color: AppColors.caramel),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _items = [];
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nouveau'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bouton "Envoyer sur Google Drive"
          if (canUpload)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadAllToDrive,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _isUploading
                      ? 'Envoi en cours...'
                      : 'Envoyer sur Google Drive ($compressedCount)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Bouton "Remplacer les originaux"
          if (canDelete)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDeleting ? null : _deleteOriginals,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_sweep),
                label: Text(
                  _isDeleting
                      ? 'Suppression...'
                      : 'Remplacer les originaux ($savedCount)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.caramel,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          if (!canDelete && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sauvegarde d\'abord tes fichiers avant de pouvoir supprimer les originaux.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startCompression,
        icon: const Icon(Icons.compress),
        label: Text('Compresser ${_items.length} fichier(s)'),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalSaved = _totalSavedBytes;
    final percent = _totalOriginalBytes == 0
        ? 0.0
        : (totalSaved / _totalOriginalBytes) * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Résumé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total original'),
                Text(_formatSize(_totalOriginalBytes),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total compressé'),
                Text(_formatSize(_totalCompressedBytes),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(height: 20),
            Text(
              'Économie : ${_formatSize(totalSaved)} (${percent.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: percent > 20 ? Colors.green.shade700 : AppColors.caramel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
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