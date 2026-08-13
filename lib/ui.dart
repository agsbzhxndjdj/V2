import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core.dart';

String fmtDate(int ms) {
  if (ms == 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day}/${d.month}/${d.year}';
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: App.tab,
      builder: (ctx, tab, _) => Scaffold(
            body: const IndexedStack(children: [
              HomePage(), HistoryPage(), DownloadsPage(), ChannelsPage()
            ]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => App.tab.value = i,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie), label: 'الأفلام'),
                NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'شاهدتها'),
                NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'تحميلاتي'),
                NavigationDestination(icon: Icon(Icons.rss_feed_outlined), selectedIcon: Icon(Icons.rss_feed), label: 'القنوات'),
              ],
            ),
          ));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false, _more = false;
  final Map<String, int?> _cursor = {};
  final Set<String> _done = {};

  List<Movie> get _source => App.scope.value == 'all' ? Store.all() : Store.moviesOf(App.scope.value);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    App.query.addListener(_syncQuery);
    if (Store.channels().isNotEmpty && Store.all().isEmpty) _refresh();
  }

  void _syncQuery() {
    if (_search.text != App.query.value) {
      _search.text = App.query.value;
      setState(() {});
    }
  }

  @override
  void dispose() {
    App.query.removeListener(_syncQuery);
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
        await Store.saveMovies(c.username, [...p.movies, ...old.where((e) => !ids.contains(e.msgId))]);
        _cursor[c.username] = p.before;
        if (p.before == null) _done.add(c.username);
      } catch (_) {}
    }));
    if (mounted) setState(() => _busy = false);
  }

  Future _loadMore() async {
    if (_more) return;
    setState(() => _more = true);
    final chs = App.scope.value == 'all' ? Store.channels() : Store.channels().where((c) => c.username == App.scope.value).toList();
    await Future.wait(chs.map((c) async {
      if (_done.contains(c.username)) return;
      try {
        final p = await Tg.fetchPage(c.username, before: _cursor[c.username]);
        if (p.movies.isEmpty || p.before == null) _done.add(c.username);
        final old = Store.moviesOf(c.username);
        final ids = old.map((e) => e.msgId).toSet();
        await Store.saveMovies(c.username, [...old, ...p.movies.where((e) => !ids.contains(e.msgId))]);
        _cursor[c.username] = p.before;
      } catch (_) {}
    }));
    if (mounted) setState(() => _more = false);
  }

  List<String> _topGenres(List<Movie> src) {
    final count = <String, int>{};
    for (final m in src) {
      for (final g in m.genres) {
        count[g] = (count[g] ?? 0) + 1;
      }
    }
    return (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(12).map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final movies = Search.run(_source, _search.text);
    final genres = _topGenres(_source);
    return Scaffold(
      appBar: AppBar(
        title: const Text('تلي سينما', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          const AccountMenu(),
        ],
      ),
      body: Store.channels().isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.movie_outlined, size: 70, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('أضف قناتك الأولى لتبدأ', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => App.tab.value = 3, icon: const Icon(Icons.add), label: const Text('إضافة قناة')),
            ]))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(controller: _scroll, slivers: [
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) { App.query.value = v; setState(() {}); },
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم الفيلم أو التصنيف أو أي كلمة من الوصف…',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { App.query.value = ''; _search.clear(); setState(() {}); }),
                      filled: true, fillColor: const Color(0xFF151B23),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                )),
                SliverToBoxAdapter(child: ValueListenableBuilder<String>(
                  valueListenable: App.scope,
                  builder: (_, scope, __) => SizedBox(height: 44,
                    child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal, children: [
                        _chip('الكل', scope == 'all', () => App.scope.value = 'all'),
                        ...Store.channels().map((c) => _chip(c.title.isEmpty ? c.username : c.title, scope == c.username, () => App.scope.value = c.username)),
                      ])),
                )),
                if (genres.isNotEmpty)
                  SliverToBoxAdapter(child: SizedBox(height: 40,
                    child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal, children: genres.map((g) => _chip(g, _search.text == g, () {
                            App.query.value = _search.text == g ? '' : g;
                            _syncQuery();
                          }, small: true)).toList()))),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((_, i) => MovieCard(m: movies[i]), childCount: movies.length),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.58, mainAxisSpacing: 8, crossAxisSpacing: 8),
                  ),
                ),
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(14), child: Center(child: _more ? const CircularProgressIndicator(strokeWidth: 2) : TextButton(onPressed: _loadMore, child: const Text('تحميل المزيد من الأفلام'))))),
              ])),
      floatingActionButton: _busy ? const CircularProgressIndicator() : null,
    );
  }

  Widget _chip(String t, bool sel, VoidCallback on, {bool small = false}) => Padding(
      padding: EdgeInsets.only(right: small ? 6 : 8),
      child: FilterChip(label: Text(t, style: TextStyle(fontSize: small ? 11 : 13)), selected: sel, onSelected: (_) => on()));
}
class MovieCard extends StatelessWidget {
  final Movie m;
  const MovieCard({super.key, required this.m});
  @override
  Widget build(BuildContext context) {
    final dl = Store.downloads().containsKey(m.id);
    final watched = Store.history().any((e) => e.id == m.id);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(m: m))),
      child: ClipRRect(borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          m.poster.isNotEmpty
              ? CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.cover, memCacheWidth: 300, placeholder: (_, __) => Container(color: const Color(0xFF151B23)), errorWidget: (_, __, ___) => _ph())
              : _ph(),
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(.88)]))),
          Positioned(top: 4, left: 4, child: Row(children: [
            if (watched) const Icon(Icons.check_circle, size: 15, color: Colors.green),
            if (dl) const Icon(Icons.download_done, size: 15, color: Colors.amber),
          ])),
          if (m.quality.isNotEmpty)
            Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical:class PlayerScreen extends StatefulWidget {
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
      final v = widget.path != null ? VideoPlayerController.file(File(widget.path!)) : VideoPlayerController.networkUrl(Uri.parse(widget.m.videoUrl));
      await v.initialize();
      Store.markWatched(widget.m);
      _v = v;
      setState(() => _c = ChewieController(videoPlayerController: v, aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio, allowFullScreen: true));
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
      body: _err ? const Center(child: Text('تعذر التشغيل — جرّب التحديث أو التحميل أولاً', style: TextStyle(color: Colors.grey))) : _c == null ? const Center(child: CircularProgressIndicator()) : Center(child: Chewie(controller: _c!)));
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        final h = Store.history();
        return Scaffold(
          appBar: AppBar(title: const Text('شاهدتها'), actions: [
            if (h.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep), onPressed: () async { for (final m in List.of(h)) { await Store.markWatchedRemove(m.id); } }),
          ]),
          body: h.isEmpty
              ? const Center(child: Text('لم تشاهد شيئًا بعد', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: h.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: h[i].poster, width: 52, height: 74, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 52, color: const Color(0xFF151B23), child: const Icon(Icons.movie, size: 22, color: Colors.grey)))),
                    title: Text(h[i].title, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(fmtDate(h[i].date), style: const TextStyle(fontSize: 10)),
                    trailing: const Icon(Icons.chevron_left, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(m: h[i]))),
                  )),
        );
      });
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Map<String, double>>(
      valueListenable: Downloader.progress,
      builder: (_, pr, __) => ValueListenableBuilder<int>(
          valueListenable: Store.tick,
          builder: (_, __, ___) {
            final done = Store.downloads();
            final active = pr.keys.where((k) => !done.containsKey(k)).toList();
            return Scaffold(
              appBar: AppBar(title: const Text('تحميلاتي')),
              body: done.isEmpty && active.isEmpty
                  ? const Center(child: Text('لا تحميلات بعد', style: TextStyle(color: Colors.grey)))
                  : ListView(children: [
                      ...active.map((id) => ListTile(
                          leading: const CircularProgressIndicator(strokeWidth: 2),
                          title: Text('جارٍ التحميل… ${(pr[id]! * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 13)),
                          trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Downloader.cancel(id)))),
                      ...done.values.map((e) {
                        final m = Movie.fromJson(Map<String, dynamic>.from(e));
                        return ListTile(
                          leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: m.poster, width: 52, height: 74, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 52, color: const Color(0xFF151B23), child: const Icon(Icons.movie, size: 22, color: Colors.grey)))),
                          title: Text(m.title, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(m.size, style: const TextStyle(fontSize: 10)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.play_arrow, color: Colors.amber), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(m: m, path: e['path'])))),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async { await Downloader.deleteFile(e['path']); await Store.delDownload(m.id); }),
                          ]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(m: m))));
                      }),
                    ]),
            );
          }));
}
 class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});
  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  Future _add() async {
    final u = Tg.cleanUser(_ctrl.text);
    if (u.isEmpty) return;
    setState(() => _busy = true);
    try {
      final p = await Tg.fetchPage(u);
      await Store.addChannel(Channel(u, title: p.title, avatar: p.avatar));
      await Store.saveMovies(u, p.movies);
      Store.sync();
      _ctrl.clear();
      App.scope.value = u;
      App.tab.value = 0;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر العثور عليها — تأكد أنها قناة عامة ولها يوزر')));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) => Scaffold(
        appBar: AppBar(title: const Text('القنوات')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          TextField(controller: _ctrl,
            decoration: InputDecoration(
              hintText: 'الصق رابط القناة أو @اليوزر أو المعرف…',
              prefixIcon: const Icon(Icons.add_link),
              suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: const Icon(Icons.add_circle, color: Colors.amber), onPressed: _add),
              filled: true, fillColor: const Color(0xFF151B23),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
          const SizedBox(height: 16),
          ListTile(
            dense: true,
            leading: const CircleAvatar(child: Icon(Icons.video_library)),
            title: const Text('الكل — جميع القنوات', style: TextStyle(fontSize: 14)),
            trailing: App.scope.value == 'all' ? const Icon(Icons.check_circle, color: Colors.amber, size: 18) : null,
            onTap: () { App.scope.value = 'all'; App.tab.value = 0; }),
          const Divider(),
          ...Store.channels().map((c) => ListTile(
                leading: CircleAvatar(backgroundImage: c.avatar != null ? NetworkImage(c.avatar!) : null, child: c.avatar == null ? const Icon(Icons.rss_feed) : null),
                title: Text(c.title.isEmpty ? c.username : c.title, style: const TextStyle(fontSize: 14)),
                subtitle: Text('@${c.username} • ${Store.moviesOf(c.username).length} فيلم', style: const TextStyle(fontSize: 11)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (App.scope.value == c.username) const Icon(Icons.check_circle, color: Colors.amber, size: 18),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => Store.delChannel(c.username)),
                ]),
                onTap: () { App.scope.value = c.username; App.tab.value = 0; },
              )),
        ]),
      ));
}

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return IconButton(
        icon: Icon(u != null ? Icons.manage_accounts : Icons.login_outlined),
        onPressed: () {
          if (u == null) { Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); return; }
          showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: CircleAvatar(child: Text(u.displayName?.isNotEmpty == true ? u.displayName![0] : 'ح')), title: Text(u.displayName ?? ''), subtitle: Text(u.email ?? '')),
            ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('تسجيل الخروج'), onTap: () async {
              await FirebaseAuth.instance.signOut();
              await Store.setGuest(true);
              App.tick.value++;
              if (context.mounted) Navigator.pop(context);
            }),
          ])));
        });
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future _google(BuildContext context) async {
    try {
      final acc = await GoogleSignIn().signIn();
      if (acc == null) return;
      final a = await acc.authentication;
      await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: a.idToken, accessToken: a.accessToken));
      await Store.sync();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFF151B23), borderRadius: BorderRadius.circular(28)), child: const Icon(Icons.movie_filter, size: 70, color: Colors.amber)),
    const SizedBox(height: 18),
    const Text('تلي سينما', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.amber)),
    const SizedBox(height: 6),
    Text('أفلام قنواتك العامة… بواجهة تليق بها', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
    const SizedBox(height: 40),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: FilledButton.icon(onPressed: () => _google(context), icon: const Icon(Icons.g_mobiledata, size: 28), label: const Text('تسجيل الدخول عبر Google'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    const SizedBox(height: 8),
    TextButton(onPressed: () async { await Store.setGuest(true); App.tick.value++; }, child: const Text('المتابعة كضيف')),
  ])));
        }                                                                                             
