import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock/wakelock.dart';
import 'core.dart';
import 'lang.dart';

/* ======== أدوات مساعدة ======== */

String _fmt(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

int _durSec(String s) {
  final p = s.split(':');
  try {
    if (p.length == 3) return int.parse(p[0]) * 3600 + int.parse(p[1]) * 60 + int.parse(p[2]);
    if (p.length == 2) return int.parse(p[0]) * 60 + int.parse(p[1]);
  } catch (_) {}
  return 0;
}

bool _isFinished(Movie m) {
  final pos = Store.getPosition(m.id);
  final tot = _durSec(m.duration);
  return pos > 0 && tot > 0 && pos >= (tot * 0.95).toInt();
}

bool _inProgress(Movie m) {
  final pos = Store.getPosition(m.id);
  return pos > 60 && !_isFinished(m);
}

/* ======== الشاشة الرئيسية للشاشة الكبيرة ======== */

class TvHome extends StatefulWidget {
  const TvHome({super.key});
  @override
  State<TvHome> createState() => _TvHomeState();
}

class _TvHomeState extends State<TvHome> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (Store.channels().isNotEmpty && Store.all().isEmpty) _refresh();
  }

  Future _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    for (final c in Store.channels()) {
      try {
        final p = await Tg.fetchPage(c.username);
        final old = Store.moviesOf(c.username);
        final ids = p.movies.map((e) => e.msgId).toSet();
        await Store.saveMovies(c.username, [...p.movies, ...old.where((e) => !ids.contains(e.msgId))]);
      } catch (_) {}
    }
    if (mounted) setState(() => _busy = false);
  }

  void _addDialog() {
    final ctrl = TextEditingController();
    bool busy = false;
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
                  backgroundColor: const Color(0xFF151B23),
                  title: Text(Lang.t('addChannel')),
                  content: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: InputDecoration(
                          hintText: Lang.t('addChannelHint'),
                          filled: true,
                          fillColor: const Color(0xFF0B0F14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Lang.t('cancel'))),
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                setS(() => busy = true);
                                final u = Tg.cleanUser(ctrl.text);
                                if (u.isNotEmpty) {
                                  try {
                                    final p = await Tg.fetchPage(u);
                                    if (p.movies.isNotEmpty) {
                                      await Store.addChannel(Channel(u, title: p.title, avatar: p.avatar));
                                      await Store.saveMovies(u, p.movies);
                                    }
                                  } catch (_) {}
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        child: Text(Lang.t('addChannel'))),
                  ],
                )));
  }

  Widget _row(String title, List<Movie> list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
            child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accent))),
        SizedBox(
            height: 250,
            child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: list.length,
                itemBuilder: (_, i) => TvCard(m: list[i]))),
      ]);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        final all = Store.all();
        final cont = all.where(_inProgress).toList();
        final chs = Store.channels();
        return Scaffold(
            body: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/iconic.png', width: 40, height: 40)),
                const SizedBox(width: 12),
                Text(Lang.t('appName'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                const Spacer(),
                if (_busy)
                  const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white70, size: 26), onPressed: _refresh),
                const SizedBox(width: 6),
                FilledButton.icon(
                    onPressed: _addDialog,
                    icon: const Icon(Icons.add_link, size: 20),
                    label: Text(Lang.t('addChannel'), style: const TextStyle(fontSize: 14)),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2430),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
              ])),
          Expanded(
              child: chs.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.live_tv, size: 90, color: AppTheme.accent),
                        const SizedBox(height: 18),
                        Text(Lang.t('noChannels'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(Lang.t('noChannelsHint'), style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 26),
                        FilledButton.icon(
                            onPressed: _addDialog,
                            icon: const Icon(Icons.add),
                            label: Text(Lang.t('addChannel'), style: const TextStyle(fontSize: 16)),
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(260, 54),
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)))),
                      ]))
                  : ListView(children: [
                      if (cont.isNotEmpty) _row(Lang.t('continueWatching'), cont.take(30).toList()),
                      if (all.isNotEmpty) _row(Lang.t('movies'), all.take(60).toList()),
                      ...chs.map((c) {
                        final l = Store.moviesOf(c.username);
                        return l.isEmpty ? const SizedBox.shrink() : _row(c.title.isEmpty ? c.username : c.title, l.take(60).toList());
                      }),
                    ])),
        ]));
      });
}

/* ======== بطاقة فيلم قابلة للتركيز بالريموت ======== */

class TvCard extends StatefulWidget {
  final Movie m;
  const TvCard({super.key, required this.m});
  @override
  State<TvCard> createState() => _TvCardState();
}

class _TvCardState extends State<TvCard> {
  final _f = FocusNode();
  bool _on = false;

  @override
  void initState() {
    super.initState();
    _f.addListener(() => setState(() => _on = _f.hasFocus));
  }

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final pos = Store.getPosition(m.id);
    final tot = _durSec(m.duration);
    return AnimatedScale(
        scale: _on ? 1.07 : 1,
        duration: const Duration(milliseconds: 160),
        child: Focus(
            focusNode: _f,
            onFocusChange: (h) {
              if (h) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 200));
            },
            child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TvPlayer(movie: m))),
                child: Container(
                    width: 160,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _on ? AppTheme.accent : Colors.transparent, width: 3),
                        color: const Color(0xFF1B2430)),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(fit: StackFit.expand, children: [
                          m.poster.isNotEmpty
                              ? CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Center(child: Icon(Icons.movie, size: 46)))
                              : const Center(child: Icon(Icons.movie, size: 46)),
                          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
                          Positioned(left: 8, right: 8, bottom: 8, child: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                          if (m.quality.isNotEmpty)
                            Positioned(top: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(6)), child: Text(m.quality, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)))),
                          if (pos > 0 && tot > 0)
                            Positioned(left: 0, right: 0, bottom: 0, child: LinearProgressIndicator(value: pos / tot, minHeight: 4, backgroundColor: Colors.black54, valueColor: AlwaysStoppedAnimation(AppTheme.accent))),
                        ]))))));
  }
}

/* ======== مشغل الفيديو بالريموت ======== */

class TvPlayer extends StatefulWidget {
  final Movie movie;
  const TvPlayer({super.key, required this.movie});
  @override
  State<TvPlayer> createState() => _TvPlayerState();
}

class _TvPlayerState extends State<TvPlayer> {
  VideoPlayerController? _c;
  bool _ready = false, _err = false, _ui = true;
  Timer? _hide, _saver;
  String _currentQuality = '';
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentQuality = widget.movie.quality;
    _currentUrl = widget.movie.videoUrl;
    Store.markWatched(widget.movie);
    WakelockPlus.enable();
    _saver = Timer.periodic(const Duration(seconds: 5), (_) => _save());
    _init();
    _poke();
  }

  Future _save() async {
    final c = _c;
    if (c != null && c.value.isInitialized) {
      final pos = c.value.position.inSeconds, dur = c.value.duration.inSeconds;
      if (pos > 10 && pos < dur - 10) await Store.savePosition(widget.movie.id, pos);
    }
  }

  Future _init({String? url}) async {
    final videoUrl = url ?? _currentUrl;
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await c.initialize();
      final saved = Store.getPosition(widget.movie.id);
      if (saved > 0) await c.seekTo(Duration(seconds: saved));
      if (!mounted) {
        c.dispose();
        return;
      }
      c.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _c = c;
        _ready = true;
      });
      c.play();
    } catch (_) {
      if (mounted) setState(() => _err = true);
    }
  }

  void _poke() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _ui = false);
    });
  }

  void _seek(int s) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final t = c.value.duration.inSeconds;
    c.seekTo(Duration(seconds: (c.value.position.inSeconds + s).clamp(0, t)));
    _poke();
  }

  void _vol(double d) {
    final c = _c;
    if (c == null) return;
    c.setVolume((c.value.volume + d).clamp(0.0, 1.0));
    _poke();
  }

  void _handleMenuKey() {
    if (widget.movie.alts.isNotEmpty) {
      _showQualitySelector();
    }
    _poke();
  }

  KeyEventResult _onKey(FocusNode n, RawKeyEvent e) {
    if (e is! RawKeyDownEvent) return KeyEventResult.handled;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.goBack) return KeyEventResult.ignored;
    final c = _c;
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.mediaPlayPause) {
      if (c != null && c.value.isInitialized) {
        c.value.isPlaying ? c.pause() : c.play();
        _poke();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) { _seek(10); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowLeft) { _seek(-10); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowUp) { _vol(0.1); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowDown) { _vol(-0.1); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.keyM || k == LogicalKeyboardKey.contextMenu) {
      _handleMenuKey();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
                Icon(Icons.settings, color: AppTheme.accent, size: 24),
                const SizedBox(width: 10),
                Text(
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
            
            Container(
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent, width: 1),
              ),
              child: ListTile(
                leading: Icon(Icons.check_circle, color: AppTheme.accent, size: 28),
                title: Text(
                  _currentQuality.isNotEmpty ? _currentQuality : 'الجودة الافتراضية',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'الجودة الحالية',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ),
            
            const SizedBox(height: 12),
            
            if (widget.movie.alts.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'جودات أخرى متاحة',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...widget.movie.alts.map((alt) {
                final q = alt['q'] ?? 'جودة أخرى';
                final url = alt['url'] ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2430),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.hd, color: Colors.white70, size: 28),
                    title: Text(
                      q,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {
                      Navigator.pop(context);
                      _switchQuality(url, q);
                    },
                  ),
                );
              }),
            ],
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _switchQuality(String newUrl, String newQuality) async {
    if (newUrl == _currentUrl) return;
    
    final oldPos = _c?.value.position ?? Duration.zero;
    
    await _c?.pause();
    _c?.dispose();
    
    setState(() {
      _ready = false;
      _err = false;
      _currentUrl = newUrl;
      _currentQuality = newQuality;
    });
    
    if (oldPos.inSeconds > 10) {
      await Store.savePosition(widget.movie.id, oldPos.inSeconds);
    }
    
    await _init(url: newUrl);
    
    final c = _c;
    if (c != null && c.value.isInitialized && oldPos.inSeconds > 0) {
      await c.seekTo(oldPos);
    }
    
    _poke();
  }

  @override
  void dispose() {
    _save();
    _saver?.cancel();
    _hide?.cancel();
    WakelockPlus.disable();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final dur = c != null && c.value.isInitialized ? c.value.duration : Duration.zero;
    final pos = c != null && c.value.isInitialized ? c.value.position : Duration.zero;
    return Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
            autofocus: true,
            onKey: _onKey,
            child: Stack(fit: StackFit.expand, children: [
              if (c != null && _ready) Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
              if (_err) Center(child: Text(Lang.t('failedPlay'), style: const TextStyle(color: Colors.grey, fontSize: 18))),
              if (!_ready && !_err) const Center(child: CircularProgressIndicator(color: Colors.amber)),
              if (_ui)
                Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent])),
                        child: Row(children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              if (_currentQuality.isNotEmpty)
                                Text(_currentQuality, style: TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.w500)),
                            ],
                          )),
                          if (c != null && c.value.isInitialized)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(c.value.isPlaying ? Icons.play_arrow : Icons.pause, color: AppTheme.accent, size: 28),
                            ),
                          if (widget.movie.alts.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.settings, color: AppTheme.accent, size: 28),
                              onPressed: _showQualitySelector,
                              tooltip: 'تغيير الجودة',
                            ),
                        ]))),
              if (_ui)
                Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent])),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Row(children: [
                            Text(_fmt(pos), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: LinearProgressIndicator(value: dur.inSeconds == 0 ? 0 : pos.inSeconds / dur.inSeconds, minHeight: 5, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation(AppTheme.accent)))),
                            Text(_fmt(dur), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          ]),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('OK تشغيل/إيقاف • يمين/يسار تقديم • أعلى/أسفل الصوت', style: TextStyle(fontSize: 12, color: Colors.white54)),
                              if (widget.movie.alts.isNotEmpty)
                                Text(' • M تغيير الجودة', style: TextStyle(fontSize: 12, color: AppTheme.accent)),
                            ],
                          ),
                        ]))),
            ])));
  }
}
