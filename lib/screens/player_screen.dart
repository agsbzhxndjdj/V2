import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/site_movie.dart';
import '../tv.dart';

class PlayerScreen extends StatefulWidget {
  final SiteMovie movie;
  const PlayerScreen({super.key, required this.movie});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _c;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _c = VideoPlayerController.networkUrl(Uri.parse(widget.movie.videoUrl));
      await _c!.initialize();
      if (mounted) {
        setState(() => _loading = false);
        await _c!.play();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (_c != null && _c!.value.isInitialized)
          Center(child: AspectRatio(
            aspectRatio: _c!.value.aspectRatio,
            child: VideoPlayer(_c!),
          )),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))),
        Positioned(
          top: 16, left: 16,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ]),
    );
  }
}
