import 'dart:convert';
import 'dart:io';

import 'package:video_player/video_player.dart';

/// Opens a gallery video from a download URL or an in-memory data URI.
Future<VideoPlayerController> openGalleryVideo(String url) async {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  if (url.startsWith('data:')) {
    final comma = url.indexOf(',');
    if (comma == -1) {
      throw const FormatException('Video data is missing.');
    }
    final bytes = base64Decode(url.substring(comma + 1));
    final file = File(
      '${Directory.systemTemp.path}/gcrm_gallery_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    await file.writeAsBytes(bytes, flush: true);
    return VideoPlayerController.file(file);
  }

  return VideoPlayerController.networkUrl(Uri.parse(url));
}
