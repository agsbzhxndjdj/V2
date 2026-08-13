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
            body: const IndexedStack(children: [
              HomePage(), HistoryPage(), DownloadsPage(), ChannelsPage()
            ]),
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
      _ctrl.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر العثور عليها — تأكد أنها قناة عامة ولها يوزر')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('القنوات')),
    body: ListView(padding: const EdgeInsets.all(12), children: [
      TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: 'الصق رابط القناة أو @اليوزر…',
          prefixIcon: const Icon(Icons.add_link),
          suffixIcon: _busy
              ? const Padding(padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(icon: const Icon(Icons.add_circle, color: Colors.amber),
                  onPressed: _add),
          filled: true, fillColor: const Color(0xFF151B23),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 16),
      ...Store.channels().map((c) => ListTile(
            leading: CircleAvatar(
                backgroundImage: c.avatar != null ? NetworkImage(c.avatar!) : null,
                child: c.avatar == null ? const Icon(Icons.rss_feed) : null),
            title: Text(c.title.isEmpty ? c.username : c.title,
                style: const TextStyle(fontSize: 14)),
            subtitle: Text('@${c.username} • ${Store.moviesOf(c.username).length} فيلم',
                style: const TextStyle(fontSize: 11)),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () async {
                  await Store.delChannel(c.username);
                  setState(() {});
                }),
          )),
    ]),
  );
}
