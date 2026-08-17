import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'core.dart';
import 'lang.dart';
import 'features.dart';
import 'auth.dart';
import 'services/sites_manager.dart';
import 'screens/sites_home_screen.dart';

/* ======== الهيكل الرئيسي ======== */
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: App.tab,
      builder: (ctx, tab, _) => Scaffold(
            body: IndexedStack(index: tab, children: const [
              HomePage(), FavoritesPage(), HistoryPage(), DownloadsPage(), ChannelsPage()
            ]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => App.tab.value = i,
              destinations: [
                NavigationDestination(icon: const Icon(Icons.movie_outlined), selectedIcon: const Icon(Icons.movie), label: Lang.t('movies')),
                NavigationDestination(icon: const Icon(Icons.favorite_outline), selectedIcon: const Icon(Icons.favorite), label: Lang.t('favorites')),
                NavigationDestination(icon: const Icon(Icons.history_outlined), selectedIcon: const Icon(Icons.history), label: Lang.t('watched')),
                NavigationDestination(icon: const Icon(Icons.download_outlined), selectedIcon: const Icon(Icons.download), label: Lang.t('downloads')),
                NavigationDestination(icon: const Icon(Icons.rss_feed_outlined), selectedIcon: const Icon(Icons.rss_feed), label: Lang.t('channels')),
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
  final _scroll = ScrollController();
  bool _searching = false;
  final _ctrl = TextEditingController();
  String _q = '', _fq = '', _fg = '';
  List<Movie> _popular = [], _reco = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadSmart();
    _scroll.addListener(() {
      if (_scroll.position.pixels > 100 && _searching) {
        setState(() => _searching = false);
      }
    });
  }

  Future _loadSmart() async {
    try {
      _popular = await Smart.popular();
      _reco = Smart.recommend(Store.all());
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _random() {
    final all = _base;
    if (all.isEmpty) return;
    final m = all[Random().nextInt(all.length)];
    Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(m: m)));
  }

  Future _refresh() async {
    await Sync.syncNow();
    if (mounted) setState(() {});
  }

  List<Movie> get _base {
    var l = Store.all();
    if (Store.getBool('hideWatched')) {
      l = l.where((m) => !_isFinished(m)).toList();
    }
    if (_q.isNotEmpty) l = Search.run(l, _q);
    if (_fq.isNotEmpty) l = l.where((m) => m.quality == _fq).toList();
    if (_fg.isNotEmpty) l = l.where((m) => m.genres.contains(_fg)).toList();
    return Sorter.apply(l, Store.sortMode);
  }

  @override
  Widget build(BuildContext context) {
    final movies = _base;
    final cont = Store.all().where(_inProgress).toList();
    final genres = <String>{};
    for (final m in movies) genres.addAll(m.genres.take(3));
    final today = movies.isEmpty ? null : movies[(DateTime.now().millisecondsSinceEpoch ~/ 86400000) % movies.length];
    final listView = Store.getBool('listView');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(Lang.t('appName')),
        actions: [
          // ✅ زرين القنوات والمواقع (يظهران فقط إذا كانت المواقع مفعلة)
          if (SitesSettings.sitesEnabled) ...[
            TextButton(
              onPressed: () => App.tab.value = 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rss_feed, size: 18, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Text('القنوات', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SitesHomeScreen()),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language, size: 18, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Text('المواقع', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _searching = !_searching)),
          IconButton(icon: const Icon(Icons.casino), onPressed: _random),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) async { await Store.setSortMode(v); setState(() {}); },
            itemBuilder: (_) => [
              _sortItem('default', 'الأحدث أولاً'),
              _sortItem('az', 'أبجدي (ذكي)'),
              _sortItem('year_desc', 'السنة: الأحدث'),
              _sortItem('year_asc', 'السنة: الأقدم'),
              _sortItem('size_desc', 'الحجم: الأكبر'),
              _sortItem('size_asc', 'الحجم: الأصغر'),
              _sortItem('smart', '✨ ذكي (حسب ذوقك)'),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
        bottom: _searching ? PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() => _q = v);
                });
              },
              decoration: InputDecoration(
                hintText: Lang.t('search'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF151B23),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ) : null,
      ),
      body: Stack(children: [
        if (Store.getBool('liveWall'))
          Positioned.fill(child: Opacity(opacity: 0.10, child: liveWallBg())),
        RefreshIndicator(
          onRefresh: _refresh,
          child: ValueListenableBuilder<String>(
            valueListenable: BulkLoader.status,
            builder: (_, status, __) => Column(children: [
              if (status.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: AppTheme.accent.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Row(children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(status, style: TextStyle(fontSize: 11, color: AppTheme.accent))),
                  ]),
                ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  children: [
                    if (today != null) _banner(today),
                    if (cont.isNotEmpty) _row(Lang.t('continueWatching'), cont),
                    if (_popular.isNotEmpty) _row(Lang.t('mostWatched'), _popular),
                    if (_reco.isNotEmpty) _row(Lang.t('recommended'), _reco),
                    _chips(genres.toList()),
                    movies.isEmpty
                        ? SizedBox(height: 200, child: Center(child: Text(Lang.t('noMovies'), style: const TextStyle(color: Colors.grey))))
                        : listView
                            ? Column(children: movies.map((m) => MovieRowItem(m: m)).toList())
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(8),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.55,
                                ),
                                itemCount: movies.length,
                                itemBuilder: (_, i) => MovieCard(m: movies[i]),
                              ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sortItem(String v, String t) => PopupMenuItem<String>(
    value: v,
    child: Row(children: [
      if (Store.sortMode == v) Icon(Icons.check, size: 16, color: AppTheme.accent),
      const SizedBox(width: 8),
      Text(t, style: const TextStyle(fontSize: 13)),
    ]));

  Widget _banner(Movie m) => Padding(
      padding: const EdgeInsets.all(10),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(m: m))),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.accent.withOpacity(0.35), Colors.transparent]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
          ),
          child: Row(children: [
            Icon(Icons.wb_sunny, color: AppTheme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Lang.t('todayPick'), style: TextStyle(fontSize: 11, color: AppTheme.accent)),
                  Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );

  Widget _row(String title, List<Movie> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accent)),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (_, i) => SizedBox(width: 130, child: MovieCard(m: list[i])),
          ),
        ),
      ],
    );

  Widget _chips(List<String> genres) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        SizedBox(
          height: 36,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            const SizedBox(width: 10),
            _chip(Lang.t('all'), _fq == '', () => setState(() => _fq = '')),
            ...['1080P', '720P', '480P'].map((q) => _chip(q, _fq == q, () => setState(() => _fq = q))),
            const SizedBox(width: 10),
          ]),
        ),
        if (genres.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              const SizedBox(width: 10),
              _chip(Lang.t('all'), _fg == '', () => setState(() => _fg = '')),
              ...genres.take(12).map((g) => _chip(g, _fg == g, () => setState(() => _fg = g))),
              const SizedBox(width: 10),
            ]),
          ),
      ]),
    );

  Widget _chip(String t, bool on, VoidCallback f) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FilterChip(
        label: Text(t, style: const TextStyle(fontSize: 11)),
        selected: on,
        onSelected: (_) => f(),
        selectedColor: AppTheme.accent.withOpacity(0.4),
      ),
    );

  @override
  void dispose() {
    _scroll.dispose();
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

/* ======== بطاقة فيلم ======== */
class MovieCard extends StatelessWidget {
  final Movie m;
  const MovieCard({super.key, required this.m});
  @override
  Widget build(BuildContext context) => Card(
      key: ValueKey('card_${m.id}_${Store.tick.value}'),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(6),
      child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(m: m))),
          child: Stack(fit: StackFit.expand, children: [
            m.poster.isNotEmpty
                ? (Store.getBool('heroFx', true)
                    ? Hero(tag: 'poster_${m.id}', child: CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.cover, placeholder: (_, __) => _ph(), errorWidget: (_, __, ___) => _ph()))
                    : CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.cover, placeholder: (_, __) => _ph(), errorWidget: (_, __, ___) => _ph()))
                : _ph(),
            Positioned(left: 0, right: 0, bottom: 0,
                child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
                    child: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
            if (m.quality.isNotEmpty)
              Positioned(top: 6, right: 6, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(6)),
                  child: Text(m.quality, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)))),
            if (Store.isPinned(m.id))
              Positioned(top: 6, left: 6, child: Icon(Icons.push_pin, size: 16, color: AppTheme.accent)),
            if (m.duration.isNotEmpty)
              Positioned(bottom: 30, left: 6, child: Text(m.duration, style: const TextStyle(fontSize: 9, color: Colors.white70))),
            if (_inProgress(m))
              Positioned(left: 6, right: 6, bottom: 0, child: LinearProgressIndicator(
                  value: Store.getPosition(m.id) / max(1, _durSec(m.duration)),
                  minHeight: 3,
                  valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                  backgroundColor: Colors.black54)),
            Positioned(top: 24, left: 4, child: Row(mainAxisSize: MainAxisSize.min, children: [
              ValueListenableBuilder<int>(valueListenable: Store.tick, builder: (_, __, ___) => IconButton(
                  icon: Icon(Store.isFav(m.id) ? Icons.favorite : Icons.favorite_border, size: 20, color: Store.isFav(m.id) ? Colors.red : Colors.white70),
                  onPressed: () => Store.toggleFav(m))),
              ValueListenableBuilder<Map<String, double>>(valueListenable: Downloader.progress, builder: (_, prog, __) => prog.containsKey(m.id)
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, value: prog[m.id]))
                  : IconButton(icon: const Icon(Icons.download_for_offline, size: 20, color: Colors.white70), onPressed: () => Downloader.start(m))),
            ])),
          ])));

  Widget _ph() => Container(color: const Color(0xFF1B2430), child: const Center(child: Icon(Icons.movie, size: 32, color: Colors.grey)));
}

/* ======== عنصر قائمة ======== */
class MovieRowItem extends StatelessWidget {
  final Movie m;
  const MovieRowItem({super.key, required this.m});
  @override
  Widget build(BuildContext context) => ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(m: m))),
      leading: ClipRRect(borderRadius: BorderRadius.circular(8),
          child: m.poster.isNotEmpty
              ? CachedNetworkImage(imageUrl: m.poster, width: 55, height: 80, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.movie))
              : const Icon(Icons.movie)),
      title: Text(m.title, style: const TextStyle(fontSize: 13)),
      subtitle: Text([m.quality, m.duration, m.size].where((e) => e.isNotEmpty).join(' • '), style: const TextStyle(fontSize: 10)),
      trailing: ValueListenableBuilder<int>(valueListenable: Store.tick, builder: (_, __, ___) => IconButton(
          icon: Icon(Store.isFav(m.id) ? Icons.favorite : Icons.favorite_border, size: 20, color: Store.isFav(m.id) ? Colors.red : Colors.grey),
          onPressed: () => Store.toggleFav(m))));
}

/* ======== صفحة المفضلة ======== */
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        final favs = Store.favorites();
        return Scaffold(
          appBar: AppBar(title: Text(Lang.t('favorites'))),
          body: favs.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  Text(Lang.t('noFavorites'), style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : ListView.builder(
                  itemCount: favs.length,
                  itemBuilder: (_, i) => MovieRowItem(m: favs[i]),
                ),
        );
      });
}

/* ======== صفحة السجل ======== */
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        final history = Store.history();
        return Scaffold(
          appBar: AppBar(title: Text(Lang.t('watched'))),
          body: history.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  Text(Lang.t('noHistory'), style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (_, i) => MovieRowItem(m: history[i]),
                ),
        );
      });
}

/* ======== صفحة التحميلات ======== */
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        final downloads = Store.downloads();
        return Scaffold(
          appBar: AppBar(title: Text(Lang.t('downloads'))),
          body: downloads.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_outlined, size: 80, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  Text(Lang.t('noDownloads'), style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : ListView.builder(
                  itemCount: downloads.length,
                  itemBuilder: (_, i) {
                    final entry = downloads.entries.elementAt(i);
                    final m = Movie.fromJson(entry.value);
                    return ListTile(
                      leading: const Icon(Icons.download_done),
                      title: Text(m.title),
                      subtitle: Text(entry.value['path'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => Store.delDownload(entry.key),
                      ),
                    );
                  },
                ),
        );
      });
}

/* ======== صفحة القنوات ======== */
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Lang.t('channelNoMovies'))));
      } else {
        await Store.addChannel(Channel(u, title: p.title, avatar: p.avatar));
        await Store.saveMovies(u, p.movies);
        BulkLoader.loadAll(u);
        _ctrl.clear();
        App.scope.value = u;
        App.tab.value = 0;
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Lang.t('serverFail'))));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) => Scaffold(
          appBar: AppBar(title: Text(Lang.t('channels'))),
          body: ListView(padding: const EdgeInsets.all(12), children: [
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              decoration: InputDecoration(
                hintText: Lang.t('addChannelHint'),
                prefixIcon: const Icon(Icons.add_link),
                suffixIcon: _busy
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(icon: Icon(Icons.add_circle, color: AppTheme.accent), onPressed: _add),
                filled: true,
                fillColor: const Color(0xFF151B23),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            if (Store.channels().isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Column(children: [
                  Icon(Icons.rss_feed, size: 90, color: AppTheme.accent),
                  const SizedBox(height: 24),
                  Text(Lang.t('noChannels'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(Lang.t('noChannelsHint'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: () => _focus.requestFocus(),
                    icon: const Icon(Icons.add),
                    label: Text(Lang.t('addChannel')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(260, 58),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ]),
              ),
            ListTile(
              dense: true,
              leading: const CircleAvatar(child: Icon(Icons.video_library, size: 20)),
              title: Text(Lang.t('allChannels'), style: const TextStyle(fontSize: 14)),
              trailing: App.scope.value == 'all' ? Icon(Icons.check_circle, color: AppTheme.accent, size: 18) : null,
              onTap: () {
                App.scope.value = 'all';
                App.tab.value = 0;
              },
            ),
            const Divider(),
            ...Store.channels().map((c) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: c.avatar != null ? NetworkImage(c.avatar!) : null,
                  child: c.avatar == null ? const Icon(Icons.rss_feed, size: 18) : null,
                ),
                title: Text(c.title.isEmpty ? c.username : c.title, style: const TextStyle(fontSize: 14)),
                subtitle: Text('@${c.username} • ${Store.moviesOf(c.username).length}', style: const TextStyle(fontSize: 11)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (App.scope.value == c.username) Icon(Icons.check_circle, color: AppTheme.accent, size: 18),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => Store.delChannel(c.username)),
                ]),
                onTap: () {
                  App.scope.value = c.username;
                  App.tab.value = 0;
                })),
          ])));

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }
}

/* ======== دوال مساعدة ======== */
bool _inProgress(Movie m) {
  final pos = Store.getPosition(m.id);
  final tot = _durSec(m.duration);
  return pos > 60 && (tot == 0 || pos < (tot * 0.95).toInt());
}

bool _isFinished(Movie m) {
  final pos = Store.getPosition(m.id);
  final tot = _durSec(m.duration);
  return pos > 0 && tot > 0 && pos >= (tot * 0.95).toInt();
}

int _durSec(String s) {
  final p = s.split(':');
  try {
    if (p.length == 3) return int.parse(p[0]) * 3600 + int.parse(p[1]) * 60 + int.parse(p[2]);
    if (p.length == 2) return int.parse(p[0]) * 60 + int.parse(p[1]);
  } catch (_) {}
  return 0;
}

Widget liveWallBg() {
  final last = Store.history().isNotEmpty ? Store.history().first : null;
  if (last == null || last.poster.isEmpty) return const SizedBox.shrink();
  return CachedNetworkImage(imageUrl: last.poster, fit: BoxFit.cover);
}
