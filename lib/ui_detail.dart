import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'core.dart';

String fmtDate(int ms) {
  if (ms == 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day}/${d.month}/${d.year}';
}

class DetailScreen extends StatelessWidget {
  final Movie m;
  const DetailScreen({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final dl = Store.downloads()[m.id];
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280, pinned: true, stretch: true,
          title: Text(m.title, style: const TextStyle(fontSize: 14)),
          flexibleSpace: FlexibleSpaceBar(background: Stack(fit: StackFit.expand, children: [
            m.poster.isNotEmpty
                ? CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox())
                : const SizedBox(),
            Container(color: Colors.black.withOpacity(.45)),
            Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, const Color(0xFF0B0F14)]))),
          ])),
        ),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Hero(tag: m.id, child: ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(imageUrl: m.poster, width: 130, height: 190,
                      fit: BoxFit.cover, errorWidget: (_, __, ___) =>
                          Container(width: 130, height: 190, color: const Color(0xFF151B23),
                              child: const Icon(Icons.movie, size: 40, color: Colors.grey)))))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (m.quality.isNotEmpty) _meta(Icons.hd, m.quality),
                  if (m.duration.isNotEmpty) _meta(Icons.schedule, m.duration),
                  if (m.size.isNotEmpty) _meta(Icons.sd_storage, m.size),
                  if (m.date != 0) _meta(Icons.calendar_month, fmtDate(m.date)),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: m.genres
                    .map((g) => ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(g, style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          App.query.value = g;
                          App.tab.value = 0;
                          Navigator.popUntil(context, (r) => r.isFirst);
                        }))
                    .toList()),
              ])),
            ]),
            const SizedBox(height: 20),
            if (m.description.isNotEmpty) ...[
              const Text('القصة', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(m.description, style: TextStyle(height: 1.8, color: Colors.grey.shade300, fontSize: 13.5)),
              const SizedBox(height: 20),
            ],
            Row(children: [
              Expanded(child: FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PlayerScreen(m: m))),
                  icon: const Icon(Icons.play_arrow), label: const Text('مشاهدة'))),
              const SizedBox(width: 10),
              if (dl != null)
                Expanded(child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PlayerScreen(m: m, path: dl['path']))),
                    icon: const Icon(Icons.folder_open), label: const Text('من الجهاز'))),
              const SizedBox(width: 10),
              ValueListenableBuilder<Map<String, double>>(
                valueListenable: Downloader.progress,
                builder: (_, pr, __) {
                  if (pr.containsKey(m.id)) {
                    return SizedBox(width: 52, height: 52, child: Stack(
                        alignment: Alignment.center, children: [
                      CircularProgressIndicator(value: pr[m.id], strokeWidth: 3),
                      IconButton(icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Downloader.cancel(m.id)),
                    ]));
                  }
                  return IconButton.filledTonal(
                      onPressed: dl != null ? null : () {
                            Downloader.start(m);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('بدأ التحميل — تابعه من تبويب تحميلاتي')));
                          },
                      icon: Icon(dl != null ? Icons.download_done : Icons.download));
                }),
            ]),
            const SizedBox(height: 24),
          ]),
        )),
      ]),
    );
  }

  Widget _meta(IconData i, String t) => Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(i, size: 14, color: Colors.amber),
      label: Text(t, style: const TextStyle(fontSize: 11)));
}

class PlayerScreen extends StatefulWidget {
  final Movie m;
  final String? path;
  const PlayerScreen({super.key, required this.m, this.path});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _v;
  ChewieController? _c;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future _init() async {
    try {
      final v = widget.path != null
          ? VideoPlayerController.file(File(widget.path!))
          : VideoPlayerController.networkUrl(Uri.parse(widget.m.videoUrl));
      await v.initialize();
      Store.markWatched(widget.m);
      _v = v;
      setState(() => _c = ChewieController(
          videoPlayerController: v,
          aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio,
          allowFullScreen: true));
    } catch (_) {
      setState(() => _err = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    _v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.m.title, style: const TextStyle(fontSize: 14))),
      body: _err
          ? const Center(child: Text('تعذر التشغيل — جرّب التحديث أو التحميل أولاً',
              style: TextStyle(color: Colors.grey)))
          : _c == null
              ? const Center(child: CircularProgressIndicator())
              : Center(child: Chewie(controller: _c!)));
}
