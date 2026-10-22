import 'package:video_player/video_player.dart';

/// Opens a gallery video from a network or data URL in the browser.
Future<VideoPlayerController> openGalleryVideo(String url) async {
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
