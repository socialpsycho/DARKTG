import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/cache_service.dart';

class PhotoViewerScreen extends StatefulWidget {
  final int fileId;
  final bool isVideo;
  final String title;

  const PhotoViewerScreen({
    super.key,
    required this.fileId,
    this.isVideo = false,
    this.title = 'Медиа',
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final Future<String?> _filePath =
      CacheService.instance.resolveFilePath(widget.fileId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
      ),
      body: FutureBuilder<String?>(
        future: _filePath,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final path = snapshot.data;
          if (path == null || path.isEmpty) {
            return const Center(
              child: Text('Не удалось загрузить файл',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          return widget.isVideo
              ? _VideoFilePlayer(path: path)
              : _PhotoFileViewer(path: path);
        },
      ),
    );
  }
}

class _PhotoFileViewer extends StatelessWidget {
  final String path;
  const _PhotoFileViewer({required this.path});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.7,
        maxScale: 5,
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white70,
            size: 56,
          ),
        ),
      ),
    );
  }
}

class _VideoFilePlayer extends StatefulWidget {
  final String path;
  const _VideoFilePlayer({required this.path});

  @override
  State<_VideoFilePlayer> createState() => _VideoFilePlayerState();
}

class _VideoFilePlayerState extends State<_VideoFilePlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _initialization = _controller.initialize().then((_) {
      _controller.setLooping(false);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Не удалось открыть видео',
                style: TextStyle(color: Colors.white70)),
          );
        }
        return Center(
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio > 0
                ? _controller.value.aspectRatio
                : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                IconButton.filled(
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                  icon: Icon(_controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF229ED9),
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
