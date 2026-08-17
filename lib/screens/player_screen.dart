// lib/screens/player_screen.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock/wakelock.dart';
import '../models/site_movie.dart';
import '../services/subtitle_service.dart';

class PlayerScreen extends StatefulWidget {
  final SiteMovie movie;

  const PlayerScreen({super.key, required this.movie});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  bool _loading = true;
  bool _showControls = true;
  VideoQuality? _selectedQuality;
  String? _subtitleContent;
  bool _subtitleEnabled = false;
  SubtitleInfo? _bestSubtitle;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initPlayer();
    _loadSubtitle();
  }

  Future<void> _initPlayer({VideoQuality? quality}) async {
    setState(() => _loading = true);

    final selectedQuality = quality ?? 
        (widget.movie.qualities.isNotEmpty 
            ? widget.movie.qualities.first 
            : null);

    if (selectedQuality == null) {
      setState(() => _loading = false);
      _showError('لا توجد جودة متاحة');
      return;
    }

    _selectedQuality = selectedQuality;

    try {
      await _videoController?.dispose();

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(selectedQuality.url),
      );

      await controller.initialize();
      
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(() {
        if (mounted) setState(() {});
      });

      setState(() {
        _videoController = controller;
        _loading = false;
      });

      await controller.play();
    } catch (e) {
      setState(() => _loading = false);
      _showError('فشل تشغيل الفيديو: $e');
    }
  }

  Future<void> _loadSubtitle() async {
    try {
      final subtitle = await SubtitleService.findBestSubtitle(
        title: widget.movie.title,
        year: widget.movie.year,
        tmdbId: widget.movie.tmdbId,
      );

      if (subtitle != null) {
        setState(() => _bestSubtitle = subtitle);
      }
    } catch (e) {
      print('Subtitle load error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showQualitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151B23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: const Color(0xFFFFC107), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'اختر الجودة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...widget.movie.qualities.map((quality) {
              final isSelected = _selectedQuality?.url == quality.url;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFFFFC107).withOpacity(0.1) 
                      : const Color(0xFF1B2430),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFFC107) : Colors.white12,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.hd,
                    color: isSelected ? const Color(0xFFFFC107) : Colors.white70,
                    size: 28,
                  ),
                  title: Text(
                    quality.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _initPlayer(quality: quality);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSubtitleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151B23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.subtitles, color: const Color(0xFFFFC107), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'الترجمة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(
                Icons.subtitles_off,
                color: !_subtitleEnabled ? const Color(0xFFFFC107) : Colors.white70,
              ),
              title: const Text(
                'بدون ترجمة',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(() => _subtitleEnabled = false);
                Navigator.pop(context);
              },
            ),
            if (_bestSubtitle != null)
              ListTile(
                leading: Icon(
                  Icons.subtitles,
                  color: _subtitleEnabled ? const Color(0xFFFFC107) : Colors.white70,
                ),
                title: Text(
                  _bestSubtitle!.language.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '⭐ ${_bestSubtitle!.rating.toStringAsFixed(1)} • ⬇️ ${_bestSubtitle!.downloadCount}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final content = await SubtitleService.downloadSubtitleContent(
                    _bestSubtitle!.fileId,
                  );
                  if (content != null && mounted) {
                    setState(() {
                      _subtitleContent = content;
                      _subtitleEnabled = true;
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoController != null && _videoController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))),

          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          Positioned(
            top: 16,
            right: 16,
            child: Row(
              children: [
                if (widget.movie.qualities.length > 1)
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: const Color(0xFFFFC107),
                      size: 28,
                    ),
                    onPressed: _showQualitySelector,
                  ),
                if (_bestSubtitle != null)
                  IconButton(
                    icon: Icon(
                      Icons.subtitles,
                      color: _subtitleEnabled ? const Color(0xFFFFC107) : Colors.white70,
                      size: 28,
                    ),
                    onPressed: _showSubtitleSelector,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
