import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'gallery_video_controller.dart';

/// Plays a gallery video with play, pause, and scrubbing controls.
class GalleryVideoPlayer extends StatefulWidget {
  final String mediaUrl;

  const GalleryVideoPlayer({
    super.key,
    required this.mediaUrl,
  });

  @override
  State<GalleryVideoPlayer> createState() => _GalleryVideoPlayerState();
}

class _GalleryVideoPlayerState extends State<GalleryVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (widget.mediaUrl.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'This video is not available.';
      });
      return;
    }

    try {
      final controller = await openGalleryVideo(widget.mediaUrl);
      await controller.initialize();
      controller.addListener(_onPlayback);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
        _playing = controller.value.isPlaying;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to play this video.';
      });
    }
  }

  void _onPlayback() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    final playing = controller.value.isPlaying;
    if (playing != _playing || controller.value.hasError) {
      setState(() {
        _playing = playing;
        if (controller.value.hasError) {
          _error = 'Unable to play this video.';
        }
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayback);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_error != null || _controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ?? 'Unable to play this video.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
        ),
      );
    }

    final controller = _controller!;
    final aspect = controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio;

    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: VideoPlayer(controller),
            ),
          ),
          if (!_playing)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFFA78BFA),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
