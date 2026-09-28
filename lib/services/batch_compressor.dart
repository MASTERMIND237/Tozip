import 'dart:io';
import '../models/media_item.dart';
import 'video_compressor.dart';
import 'image_compressor.dart';

class BatchProgress {
  final int current;
  final int total;
  final MediaItem item;

  BatchProgress({
    required this.current,
    required this.total,
    required this.item,
  });

  double get fraction => total == 0 ? 0 : current / total;
}

class BatchCompressor {
  static Future<void> compressAll(
    List<MediaItem> items, {
    required void Function(BatchProgress) onProgress,
    required void Function(MediaItem) onItemDone,
    required void Function() onComplete,
  }) async {
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      item.isProcessing = true;
      onProgress(BatchProgress(current: i + 1, total: items.length, item: item));

      try {
        item.originalSize = await File(item.originalPath).length();

        if (item.type == MediaType.video) {
          final result = await VideoCompressor.compress(
            inputPath: item.originalPath,
            crf: 23,
            preset: 'medium',
          );
          item.compressedPath = result.compressedPath;
          item.compressedSize = result.compressedSize;
        } else {
          final result = await ImageCompressor.compress(
            inputPath: item.originalPath,
            quality: 85,
          );
          item.compressedPath = result.compressedPath;
          item.compressedSize = result.compressedSize;
        }

        item.isDone = true;
      } catch (e) {
        item.error = e.toString();
      } finally {
        item.isProcessing = false;
        onItemDone(item);
      }
    }
    onComplete();
  }
}