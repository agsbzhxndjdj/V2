import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'core.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: App.tab,
      builder: (ctx, tab, _) => Scaffold(
            body: IndexedStack(
              index: tab,
              children: const [
                HomePage(), HistoryPage(), DownloadsPage(), ChannelsPage()
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => App.tab.value = i,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.movie), label: 'الأفلام'),
                NavigationDestination(icon: Icon(Icons.history), label: 'شاهدتها'),
                NavigationDestination(icon: Icon(Icons.download), label: 'تحميلاتي'),
                NavigationDestination(icon: Icon(Icons.rss_feed), label: 'القنوات'),
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

  @override
  void initState() {
    super.initState();
    if (Store.channels().isNotEmpty && Store.all().isEmpty) _refresh();
  }

  Future _refresh() async {
    await Future.wait(Store.channels().map((c) async {
      try {
        final p = await Tg.fetchPage(c.username);
        await Store.saveMovies(c.username, p.movies);
      } catch (_) {}
    }));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movies = Search.run(Store.all(), _search.text);
    return Scaffold(
      appBar: AppBar(title: const Text('تلي سينما'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ابحث عن فيلم…',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true, fillColor: const Color(0xFF151B23),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 0.55,
                mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: movies.length,
            itemBuilder: (_, i) => MovieCard(m: movies[i]),
          ),
        ),
      ]),
    );
  }
}

class MovieCard extends StatelessWidget {
  final Movie m;
  const MovieCard({super.key, required this.m});
  @override
  Widget build(BuildContext context) {
    final dl = Store.downloads().containsKey(m.id);
    final watched = Store.history().any((e) => e.id == m.id);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(m: m))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Column(children: [
            Expanded(child: CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF151B23)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF151B23),
                    child: const Icon(Icons.movie_outlined, size: 40, color: Colors.grey)))),
            Padding(padding: const EdgeInsets.all(4),
                child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
          Positioned(top: 4, left: 4, child: Row(children: [
            if (watched) const Icon(Icons.check_circle, size: 15, color: Colors.green),
            if (dl) const Icon(Icons.download_done, size: 15, color: Colors.amber),
          ])),
          if (m.quality.isNotEmpty)
            Positioned(top: 4, right: 4, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                child: Text(m.quality, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)))),
        ]),
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final Movie m;
  const DetailScreen({super.key, required this.m});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(m.title)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(imageUrl: m.poster, height: 300, width: double.infinity, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(height: 300, color: const Color(0xFF151B23),
                    child: const Icon(Icons.movie, size: 60, color: Colors.grey)))),
        const SizedBox(height: 16),
        Text(m.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (m.genres.isNotEmpty)
          Text(m.genres.join(' | '), style: const TextStyle(color: Colors.amber, fontSize: 13)),
        const SizedBox(height: 8),
        Text(m.description, style: TextStyle(height: 1.7, color: Colors.grey.shade300, fontSize: 13.5)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => PlayerScreen(m: m))),
            icon: const Icon(Icons.play_arrow), label: const Text('مشاهدة'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: () {
              Downloader.start(m);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('بدأ التحميل — تابعه من تبويب تحميلاتي')));
            },
            icon: const Icon(Icons.download), label: const Text('تحميل'))),
        ]),
      ]),
    ),
  );
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
      setState(() => _c = ChewieController(videoPlayerController: v,
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
            : Center(child: Chewie(controller: _c!)),
  );
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final h = Store.history();
    return Scaffold(
      appBar: AppBar(title: const Text('شاهدتها')),
      body: h.isEmpty
          ? const Center(child: Text('لم تشاهد شيئًا بعد', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: h.length,
              itemBuilder: (_, i) => ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(imageUrl: h[i].poster,
                        width: 52, height: 74, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(width: 52,
                            color: const Color(0xFF151B23),
                            child: const Icon(Icons.movie, size: 22, color: Colors.grey)))),
                title: Text(h[i].title, style: const TextStyle(fontSize: 13)),
                trailing: const Icon(Icons.chevron_left, color: Colors.grey),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DetailScreen(m: h[i]))),
              )),
    );
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = Store.downloads().values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('تحميلاتي')),
      body: d.isEmpty
          ? const Center(child: Text('لا تحميلات بعد', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: d.length,
              itemBuilder: (_, i) {
                final m = Movie.fromJson(Map<String, dynamic>.from(d[i]));
                return ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: m.poster,
                          width: 52, height: 74, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(width: 52,
                              color: const Color(0xFF151B23),
                              child: const Icon(Icons.movie, size: 22, color: Colors.grey)))),
                  title: Text(m.title, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(m.size, style: const TextStyle(fontSize: 10)),
                  trailing: IconButton(icon: const Icon(Icons.play_arrow, color: Colors.amber),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PlayerScreen(m: m, path: d[i]['path'])))),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DetailScreen(m: m))),
                );
              }),
    );
  }
}

class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});
  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  bool _busy = false;

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s), behavior: SnackBarBehavior.floating));

  Future _add(String input) async {
    final u = Tg.cleanUser(input);
    if (u.isEmpty) {
      _snack('اكتب رابط القناة أو اسم المستخدم أولًا');
      return;
    }
    setState(() => _busy = true);
    _snack('جارٍ فحص القناة وجلب أفلامها…');
    try {
      final p = await Tg.fetchPage(u);
      await Store.addChannel(Channel(u, title: p.title, avatar: p.avatar));
      await Store.saveMovies(u, p.movies);
      if (mounted) {
        _snack(p.movies.isEmpty
            ? 'تمت الإضافة ✅ لكن لا توجد فيديوهات في القناة بعد'
            : 'تمت إضافة «${p.title}» بنجاح ✅');
      }
    } catch (_) {
      if (mounted) _snack('تعذر العثور على القناة — تأكد أنها عامة ولها يوزر');
    }
    if (mounted) setState(() => _busy = false);
  }

  void _openAddSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151B23),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Row(children: [
            Icon(Icons.add_circle, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('إضافة قناة جديدة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text('تعمل القنوات العامة فقط (التي تظهر أفلامها لأي زائر)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              hintText: '@username  أو  t.me/username',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.link, color: Colors.amber),
              filled: true, fillColor: const Color(0xFF0B0F14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                final v = ctrl.text.trim();
                Navigator.pop(context);
                _add(v);
              },
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('إضافة القناة', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chs = Store.channels();
    return Scaffold(
      appBar: AppBar(title: const Text('القنوات')),
      body: chs.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.rss_feed, size: 80, color: Colors.amber.shade700),
                const SizedBox(height: 16),
                const Text('لا توجد قنوات بعد',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('أضف قناة أفلام عامة من تليجرام وستظهر جميع فيديوهاتها هنا بواجهة سينما',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _openAddSheet,
                    icon: _busy
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add),
                    label: const Text('إضافة قناة', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ]),
            ))
          : ListView(padding: const EdgeInsets.all(12), children: [
              ...chs.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0B0F14),
                            backgroundImage:
                                c.avatar != null ? NetworkImage(c.avatar!) : null,
                            child: c.avatar == null
                                ? const Icon(Icons.rss_feed, color: Colors.amber)
                                : null),
                        title: Text(c.title.isEmpty ? c.username : c.title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '@${c.username} • ${Store.moviesOf(c.username).length} فيلم',
                            style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              await Store.delChannel(c.username);
                              setState(() {});
                            }),
                      ),
                    ),
                  )),
            ]),
      floatingActionButton: chs.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _openAddSheet,
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              label: const Text('إضافة قناة'),
            ),
    );
  }
}
