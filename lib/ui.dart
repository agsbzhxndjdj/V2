import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'core.dart';

String _fmt(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/* ======== الهيكل الرئيسي (5 تبويبات) ======== */
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: App.tab,
      builder: (ctx, tab, _) => Scaffold(
            body: IndexedStack(index: tab, children: const [
              HomePage(),
              FavoritesPage(),
              HistoryPage(),
              DownloadsPage(),
              ChannelsPage()
            ]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => App.tab.value = i,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.movie_outlined),
                    selectedIcon: Icon(Icons.movie),
                    label: 'الأفلام'),
                NavigationDestination(
                    icon: Icon(Icons.favorite_outline),
                    selectedIcon: Icon(Icons.favorite),
                    label: 'المفضلة'),
                NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: 'شاهدتها'),
                NavigationDestination(
                    icon: Icon(Icons.download_outlined),
                    selectedIcon: Icon(Icons.download),
                    label: 'تحميلاتي'),
                NavigationDestination(
                    icon: Icon(Icons.rss_feed_outlined),
                    selectedIcon: Icon(Icons.rss_feed),
                    label: 'القنوات'),
              ],
            ),
          ));
}

/* ======== صفحة الأفلام ======== */
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false, _more = false, _searching = false;
  final Map<String, int?> _cursor = {};
  final Set<String> _done = {};

  List<Movie> get _source =>
      App.scope.value == 'all' ? Store.all() : Store.moviesOf(App.scope.value);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    if (Store.channels().isNotEmpty && Store.all().isEmpty) _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future.wait(Store.channels().map((c) async {
      try {
        final p = await Tg.fetchPage(c.username);
        final old = Store.moviesOf(c.username);
        final ids = p.movies.map((e) => e.msgId).toSet();
        await Store.saveMovies(c.username,
            [...p.movies, ...old.where((e) => !ids.contains(e.msgId))]);
        _cursor[c.username] = p.before;
        if (p.before == null) _done.add(c.username);
      } catch (_) {}
    }));
    if (mounted) setState(() => _busy = false);
  }

  Future _loadMore() async {
    if (_more) return;
    setState(() => _more = true);
    final chs = App.scope.value == 'all'
        ? Store.channels()
        : Store.channels()
            .where((c) => c.username == App.scope.value)
            .toList();
    await Future.wait(chs.map((c) async {
      if (_done.contains(c.username)) return;
      try {
        final p = await Tg.fetchPage(c.username, before: _cursor[c.username]);
        if (p.movies.isEmpty || p.before == null) _done.add(c.username);
        final old = Store.moviesOf(c.username);
        final ids = old.map((e) => e.msgId).toSet();
        await Store.saveMovies(c.username,
            [...old, ...p.movies.where((e) => !ids.contains(e.msgId))]);
        _cursor[c.username] = p.before;
      } catch (_) {}
    }));
    if (mounted) setState(() => _more = false);
  }

  @override
  Widget build(BuildContext context) {
    final movies = Search.run(_source, _search.text);
    return Scaffold(
      appBar: AppBar(title: const Text('تلي سينما'), actions: [
        IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = !_searching)),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
      ], bottom: _searching
          ? PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          hintText: 'ابحث عن فيلم…',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFF151B23),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none)))))
          : null),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: movies.isEmpty
            ? ListView(children: const [
                SizedBox(height: 150),
                Center(
                    child: Text('لا توجد أفلام بعد — أضف قناة من تبويب القنوات',
                        style: TextStyle(color: Colors.grey)))
              ])
            : GridView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, childAspectRatio: 0.55),
                itemCount: movies.length,
                itemBuilder: (_, i) => MovieCard(m: movies[i]),
              ),
      ),
    );
  }
}

/* ======== بطاقة فيلم ======== */
class MovieCard extends StatelessWidget {
  final Movie m;
  const MovieCard({super.key, required this.m});

  Widget _ph() => Container(
      color: const Color(0xFF1B2430),
      child: const Center(
          child: Icon(Icons.movie_filter, size: 42, color: Colors.amber)));

  @override
  Widget build(BuildContext context) => Card(
        key: ValueKey('card_${m.id}_${Store.tick.value}'),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.all(6),
        child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => MovieDetailsScreen(m: m))),
          child: Stack(fit: StackFit.expand, children: [
            m.poster.isNotEmpty
                ? CachedNetworkImage(
                    key: ValueKey('poster_${m.id}_${Store.tick.value}'),
                    imageUrl: m.poster,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeOutDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => _ph(),
                    errorWidget: (_, __, ___) => _ph())
                : _ph(),
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87])),
                    child: Text(m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)))),
            if (m.quality.isNotEmpty)
              Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(m.quality,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)))),
            if (m.duration.isNotEmpty)
              Positioned(
                  bottom: 30,
                  left: 6,
                  child: Text(m.duration,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.white70))),
            Positioned(
                top: 4,
                left: 4,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ValueListenableBuilder<int>(
                      valueListenable: Store.tick,
                      builder: (_, __, ___) => IconButton(
                          icon: Icon(
                              Store.isFav(m.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 20,
                              color: Store.isFav(m.id)
                                  ? Colors.red
                                  : Colors.white70),
                          onPressed: () => Store.toggleFav(m))),
                  ValueListenableBuilder<Map<String, double>>(
                      valueListenable: Downloader.progress,
                      builder: (_, prog, __) => prog.containsKey(m.id)
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, value: prog[m.id]))
                          : IconButton(
                              icon: const Icon(Icons.download_for_offline,
                                  size: 20, color: Colors.white70),
                              onPressed: () => Downloader.start(m))),
                ])),
          ]),
        ),
      );
}

/* ======== شاشة تفاصيل الفيلم ======== */
class MovieDetailsScreen extends StatelessWidget {
  final Movie m;
  const MovieDetailsScreen({super.key, required this.m});

  Widget _chip(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFF1B2430),
          borderRadius: BorderRadius.circular(20)),
      child: Text(t,
          style: const TextStyle(fontSize: 11, color: Color(0xFFE5B13D))));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        body: Stack(fit: StackFit.expand, children: [
          if (m.poster.isNotEmpty)
            CachedNetworkImage(
                key: ValueKey('details_${m.id}_${Store.tick.value}'),
                imageUrl: m.poster,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: const Duration(milliseconds: 200),
                errorWidget: (_, __, ___) => const SizedBox()),
          Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                Colors.black87,
                Colors.transparent,
                Color(0xFF0B0F14)
              ]))),
          SafeArea(
              child: Column(children: [
            Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
              Expanded(
                  child: Text(m.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              ValueListenableBuilder<int>(
                  valueListenable: Store.tick,
                  builder: (_, __, ___) => IconButton(
                      icon: Icon(
                          Store.isFav(m.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Store.isFav(m.id)
                              ? Colors.red
                              : Colors.white70),
                      onPressed: () => Store.toggleFav(m))),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      if (m.quality.isNotEmpty) _chip(m.quality),
                      if (m.duration.isNotEmpty) _chip(m.duration),
                      if (m.size.isNotEmpty) _chip(m.size),
                      ...m.genres.map(_chip),
                    ]),
                    if (m.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: SingleChildScrollView(
                              child: Text(m.description,
                                  style: TextStyle(
                                      color: Colors.grey.shade300,
                                      fontSize: 13,
                                      height: 1.6)))),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: FilledButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PlayerScreen(
                                          title: m.title,
                                          url: m.videoUrl,
                                          movie: m))),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('تشغيل'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFE5B13D),
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14))))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: () {
                                Downloader.start(m);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'بدأ التحميل — تابعه في تبويب تحميلاتي')));
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('تحميل'),
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  foregroundColor: const Color(0xFFE5B13D),
                                  side: const BorderSide(
                                      color: Color(0xFFE5B13D)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14))))),
                    ]),
                  ]),
            ),
          ])),
        ]),
      );
}

/* ======== المشغل الاحترافي ======== */
class PlayerScreen extends StatefulWidget {
  final String title;
  final String? url;
  final String? filePath;
  final Movie? movie;
  const PlayerScreen(
      {super.key,
      required this.title,
      this.url,
      this.filePath,
      this.movie});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  VideoPlayerController? _c;
  bool _ready = false, _err = false, _ui = true;
  Timer? _hide;
  Timer? _posSaver;
  bool _isLandscape = true;
  Offset? _start;
  int _gmode = 0;
  String _glabel = '';
  double _vol = 1.0, _bright = 1.0;
  int _seekBase = 0, _seekDelta = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.movie != null) Store.markWatched(widget.movie!);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    VolumeController().showSystemUI = false;
    VolumeController().listener((v) {
      if (mounted) setState(() => _vol = v);
    });
    _init();
    _poke();
    _startPositionSaver();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _savePosition();
      _c?.pause();
    } else if (state == AppLifecycleState.resumed) {
      final c = _c;
      if (c != null && c.value.isInitialized) {
        c.play();
        _poke();
      }
    }
  }

  void _startPositionSaver() {
    _posSaver = Timer.periodic(const Duration(seconds: 5), (_) {
      _savePosition();
    });
  }

  Future _savePosition() async {
    final c = _c;
    if (c != null && c.value.isInitialized && widget.movie != null) {
      final pos = c.value.position.inSeconds;
      final dur = c.value.duration.inSeconds;
      if (pos > 10 && pos < dur - 10) {
        await Store.savePosition(widget.movie!.id, pos);
      }
    }
  }

  Future _init() async {
    try {
      final c = widget.filePath != null
          ? VideoPlayerController.file(File(widget.filePath!))
          : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      c.addListener(() {
        if (mounted) setState(() {});
      });
      await c.initialize();
      if (widget.movie != null) {
        final savedPos = Store.getPosition(widget.movie!.id);
        if (savedPos > 0) {
          await c.seekTo(Duration(seconds: savedPos));
        }
      }
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _ready = true;
      });
      c.setVolume(1);
      final sv = await VolumeController().getVolume();
      if (mounted && sv != null) setState(() => _vol = sv);
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

  void _jump(int sec) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final t = c.value.duration.inSeconds;
    final s = (c.value.position.inSeconds + sec).clamp(0, t);
    c.seekTo(Duration(seconds: s));
    setState(() {
      _gmode = 1;
      _glabel = '${sec > 0 ? '+' : ''}$sec ثانية';
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _gmode = 0);
    });
  }

  @override
  void dispose() {
    _savePosition();
    _posSaver?.cancel();
    VolumeController().removeListener();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    _hide?.cancel();
    _c?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final dur = c != null && c.value.isInitialized
        ? c.value.duration
        : Duration.zero;
    final pos = c != null && c.value.isInitialized
        ? c.value.position
        : Duration.zero;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (c != null && _ready)
          Center(
              child: AspectRatio(
                  aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
        IgnorePointer(
            child: Container(
                color: Colors.black.withOpacity((1 - _bright) * 0.85))),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _ui = !_ui);
            if (_ui) _poke();
          },
          onDoubleTapDown: (d) {
            final w = MediaQuery.of(context).size.width;
            _jump(d.localPosition.dx > w / 2 ? 10 : -10);
          },
          onHorizontalDragStart: (d) {
            _start = d.localPosition;
            _seekBase = pos.inSeconds;
            _seekDelta = 0;
          },
          onHorizontalDragUpdate: (d) {
            _seekDelta =
                ((d.localPosition.dx - (_start?.dx ?? 0)) * 0.1).round();
            setState(() {
              _gmode = 1;
              _glabel =
                  '${_seekDelta >= 0 ? '+' : ''}$_seekDelta ث → ${_fmt(Duration(seconds: (_seekBase + _seekDelta).clamp(0, dur.inSeconds)))}';
            });
          },
          onHorizontalDragEnd: (_) {
            final s = (_seekBase + _seekDelta).clamp(0, dur.inSeconds);
            c?.seekTo(Duration(seconds: s));
            setState(() => _gmode = 0);
          },
          onVerticalDragStart: (d) {
            final w = MediaQuery.of(context).size.width;
            _start = d.localPosition;
            setState(() => _gmode = d.localPosition.dx > w / 2 ? 2 : 3);
          },
          onVerticalDragUpdate: (d) {
            final dy = (_start?.dy ?? 0) - d.localPosition.dy;
            final step = dy / 400;
            if (_gmode == 2) {
              _vol = (_vol + step).clamp(0.0, 1.0);
              VolumeController().setVolume(_vol);
              setState(() => _glabel = '${(_vol * 100).round()}%');
            } else if (_gmode == 3) {
              _bright = (_bright + step).clamp(0.0, 1.0);
              setState(() => _glabel = '${(_bright * 100).round()}%');
            }
            _start = d.localPosition;
          },
          onVerticalDragEnd: (_) => setState(() => _gmode = 0),
          child: Container(color: Colors.transparent),
        ),
        if (_gmode != 0)
          Center(
              child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        _gmode == 2
                            ? Icons.volume_up
                            : _gmode == 3
                                ? Icons.brightness_6
                                : Icons.fast_forward,
                        color: Colors.amber,
                        size: 34),
                    const SizedBox(height: 6),
                    Text(_glabel,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ]))),
        if (_ready && c != null && c.value.isBuffering)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFFE5B13D))),
        if (_err)
          const Center(
              child: Text('تعذر تشغيل الفيديو — تحقق من الاتصال',
                  style: TextStyle(color: Colors.grey))),
        if (!_ready && !_err)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFFE5B13D))),
        if (_ui)
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent])),
                  child: SafeArea(
                      child: Row(children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context)),
                    Expanded(
                        child: Text(widget.title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    IconButton(
                        icon: Icon(
                            _isLandscape
                                ? Icons.stay_current_portrait
                                : Icons.stay_current_landscape,
                            color: Colors.white70),
                        onPressed: () {
                          setState(() => _isLandscape = !_isLandscape);
                          SystemChrome.setPreferredOrientations(_isLandscape
                              ? [
                                  DeviceOrientation.landscapeLeft,
                                  DeviceOrientation.landscapeRight,
                                ]
                              : [DeviceOrientation.portraitUp]);
                        }),
                  ])))),
        if (_ui && _ready && c != null)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent])),
                  child: SafeArea(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          IconButton(
                              icon: const Icon(Icons.replay_10,
                                  color: Colors.white70),
                              onPressed: () => _jump(-10)),
                          IconButton(
                              icon: Icon(
                                  c.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.amber,
                                  size: 44),
                              onPressed: () {
                                c.value.isPlaying ? c.pause() : c.play();
                                _poke();
                              }),
                          IconButton(
                              icon: const Icon(Icons.forward_10,
                                  color: Colors.white70),
                              onPressed: () => _jump(10)),
                        ]),
                        Row(children: [
                          Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(_fmt(pos),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white70))),
                          Expanded(
                              child: SliderTheme(
                                  data: SliderThemeData(
                                      activeTrackColor:
                                          const Color(0xFFE5B13D),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: const Color(0xFFE5B13D),
                                      trackHeight: 3,
                                      thumbShape:
                                          const RoundSliderThumbShape(
                                              enabledThumbRadius: 7)),
                                  child: Slider(
                                      value: pos.inSeconds
                                          .toDouble()
                                          .clamp(0, dur.inSeconds.toDouble()),
                                      max: dur.inSeconds
                                          .toDouble()
                                          .clamp(1, 100000000),
                                      onChanged: (v) =>
                                          c.seekTo(Duration(seconds: v.toInt()))))),
                          Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(_fmt(dur),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white70))),
                        ]),
                      ])))),
      ]),
    );
  }
}

/* ======== المفضلة ======== */
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        final favs = Store.favorites();
        return Scaffold(
            appBar: AppBar(title: const Text('المفضلة')),
            body: favs.isEmpty
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.favorite_outline,
                          size: 80, color: Colors.red),
                      SizedBox(height: 16),
                      Text('لا توجد أفلام مفضلة بعد',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('اضغط على القلب ❤️ في أي فيلم لإضافته هنا',
                          style: TextStyle(color: Colors.grey)),
                    ]))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, childAspectRatio: 0.55),
                    itemCount: favs.length,
                    itemBuilder: (_, i) => MovieCard(m: favs[i])));
      });
}

/* ======== شاهدتها ======== */
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        final h = Store.history();
        return Scaffold(
            appBar: AppBar(title: const Text('شاهدتها')),
            body: h.isEmpty
                ? const Center(
                    child: Text('لا يوجد سجل مشاهدة بعد',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: h.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.history, size: 20)),
                        title: Text(h[i].title,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text('@${h[i].channel}',
                            style: const TextStyle(fontSize: 11)),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                    title: h[i].title,
                                    url: h[i].videoUrl,
                                    movie: h[i]))),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: () =>
                                Store.markWatchedRemove(h[i].id)))));
      });
}

/* ======== تحميلاتي (نشطة + مكتملة) ======== */
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  Widget _activeTile(String id) {
    final m = Downloader.movieOf(id);
    if (m == null) return const SizedBox.shrink();
    final p = Downloader.progress.value[id] ?? 0;
    final paused = Downloader.isPaused(id);
    return Card(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(paused ? Icons.pause_circle_outline : Icons.downloading,
                color: paused ? Colors.grey : const Color(0xFFE5B13D),
                size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Text(m.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            Text('${(p * 100).round()}%',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE5B13D),
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: p,
              minHeight: 5,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE5B13D))),
          const SizedBox(height: 6),
          Row(children: [
            Text(paused ? 'متوقف مؤقتاً' : 'جاري التحميل…',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const Spacer(),
            IconButton(
                tooltip: paused ? 'استئناف' : 'إيقاف مؤقت',
                icon: Icon(paused ? Icons.play_arrow : Icons.pause,
                    size: 22, color: paused ? Colors.green : Colors.amber),
                onPressed: () =>
                    paused ? Downloader.resume(id) : Downloader.pause(id)),
            IconButton(
                tooltip: 'إلغاء',
                icon: const Icon(Icons.close, size: 22, color: Colors.red),
                onPressed: () => Downloader.cancel(id)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Downloader.tick,
      builder: (_, __, ___) => ValueListenableBuilder<Map<String, double>>(
          valueListenable: Downloader.progress,
          builder: (_, prog, __) => ValueListenableBuilder<int>(
              valueListenable: Store.tick,
              builder: (_, ___, ____) {
                final active = Downloader.activeIds();
                final items = Store.downloads().entries.toList();
                return Scaffold(
                    appBar: AppBar(title: const Text('تحميلاتي')),
                    body: (active.isEmpty && items.isEmpty)
                        ? const Center(
                            child: Text('لا توجد تحميلات',
                                style: TextStyle(color: Colors.grey)))
                        : ListView(children: [
                            ...active.map(_activeTile),
                            if (active.isNotEmpty && items.isNotEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text('المكتملة',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey))),
                            ...items.map((e) {
                              final m = Movie.fromJson(
                                  Map<String, dynamic>.from(e.value));
                              final path = e.value['path']?.toString() ?? '';
                              return ListTile(
                                  leading: const CircleAvatar(
                                      child:
                                          Icon(Icons.download_done, size: 20)),
                                  title: Text(m.title,
                                      style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(m.size.isEmpty ? path : m.size,
                                      style: const TextStyle(fontSize: 10)),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => PlayerScreen(
                                              title: m.title,
                                              filePath: path))),
                                  trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      onPressed: () async {
                                        await Downloader.deleteFile(path);
                                        await Store.delDownload(e.key);
                                      }));
                            }),
                          ]));
              })));
}

/* ======== القنوات ======== */
class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});
  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  Future _add() async {
    final u = Tg.cleanUser(_ctrl.text);
    if (u.isEmpty) return;
    setState(() => _busy = true);
    try {
      final p = await Tg.fetchPage(u);
      if (p.movies.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('لم يتم العثور على أفلام في هذه القناة')));
        }
      } else {
        await Store.addChannel(Channel(u, title: p.title, avatar: p.avatar));
        await Store.saveMovies(u, p.movies);
        _ctrl.clear();
        App.scope.value = u;
        App.tab.value = 0;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر الاتصال بالخادم — تأكد أن البوت يعمل')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) => Scaffold(
            appBar: AppBar(title: const Text('القنوات')),
            body: ListView(padding: const EdgeInsets.all(12), children: [
              TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  decoration: InputDecoration(
                      hintText: 'الصق رابط القناة أو @اليوزر…',
                      prefixIcon: const Icon(Icons.add_link),
                      suffixIcon: _busy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Colors.amber),
                              onPressed: _add),
                      filled: true,
                      fillColor: const Color(0xFF151B23),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none))),
              const SizedBox(height: 16),
              if (Store.channels().isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Column(children: [
                      const Icon(Icons.rss_feed,
                          size: 90, color: Color(0xFFE5A83B)),
                      const SizedBox(height: 24),
                      const Text('لا توجد قنوات بعد',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text(
                          'أضف قناة أفلام من تيليجرام وستظهر جميع فيديوهاتها هنا',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 30),
                      FilledButton.icon(
                          onPressed: () => _focus.requestFocus(),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة قناة'),
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE5B13D),
                              foregroundColor: Colors.black,
                              minimumSize: const Size(260, 58),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)))),
                    ])),
              ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                      child: Icon(Icons.video_library, size: 20)),
                  title: const Text('الكل — جميع القنوات',
                      style: TextStyle(fontSize: 14)),
                  trailing: App.scope.value == 'all'
                      ? const Icon(Icons.check_circle,
                          color: Colors.amber, size: 18)
                      : null,
                  onTap: () {
                    App.scope.value = 'all';
                    App.tab.value = 0;
                  }),
              const Divider(),
              ...Store.channels().map((c) => ListTile(
                    leading: CircleAvatar(
                        backgroundImage: c.avatar != null
                            ? NetworkImage(c.avatar!)
                            : null,
                        child: c.avatar == null
                            ? const Icon(Icons.rss_feed, size: 18)
                            : null),
                    title: Text(c.title.isEmpty ? c.username : c.title,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                        '@${c.username} • ${Store.moviesOf(c.username).length} فيلم',
                        style: const TextStyle(fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (App.scope.value == c.username)
                        const Icon(Icons.check_circle,
                            color: Colors.amber, size: 18),
                      IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => Store.delChannel(c.username)),
                    ]),
                    onTap: () {
                      App.scope.value = c.username;
                      App.tab.value = 0;
                    },
                  )),
            ]),
          ));
}
