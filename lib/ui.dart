import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:video_player/video_player.dart';
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
  Widget build(BuildContext context) {
    final movies = Search.run(Store.all(), _search.text);
    return Scaffold(
      appBar: AppBar(title: const Text('تلي سينما'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        const AccountMenu(),
      ]),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.55),
        itemCount: movies.length,
        itemBuilder: (_, i) => MovieCard(m: movies[i]),
      ),
    );
  }
}

class MovieCard extends StatelessWidget {
  final Movie m;
  const MovieCard({super.key, required this.m});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(m: m))),
    child: Card(
      child: Column(children: [
        Expanded(child: CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.cover)),
        Padding(padding: const EdgeInsets.all(4), child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
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
        CachedNetworkImage(imageUrl: m.poster, height: 300, fit: BoxFit.cover),
        const SizedBox(height: 16),
        Text(m.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(m.description),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(m: m))),
          icon: const Icon(Icons.play_arrow),
          label: const Text('مشاهدة'),
        ),
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future _init() async {
    final v = widget.path != null
        ? VideoPlayerController.file(File(widget.path!))
        : VideoPlayerController.networkUrl(Uri.parse(widget.m.videoUrl));
    await v.initialize();
    Store.markWatched(widget.m);
    _v = v;
    setState(() => _c = ChewieController(videoPlayerController: v, aspectRatio: 16/9));
  }

  @override
  void dispose() {
    _c?.dispose();
    _v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.m.title)),
    body: _c == null ? const Center(child: CircularProgressIndicator()) : Chewie(controller: _c!),
  );
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final h = Store.history();
    return Scaffold(
      appBar: AppBar(title: const Text('شاهدتها')),
      body: ListView.builder(
        itemCount: h.length,
        itemBuilder: (_, i) => ListTile(
          leading: CachedNetworkImage(imageUrl: h[i].poster, width: 50, height: 70, fit: BoxFit.cover),
          title: Text(h[i].title),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(m: h[i]))),
        ),
      ),
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
      body: ListView.builder(
        itemCount: d.length,
        itemBuilder: (_, i) {
          final m = Movie.fromJson(Map<String, dynamic>.from(d[i]));
          return ListTile(
            leading: CachedNetworkImage(imageUrl: m.poster, width: 50, height: 70, fit: BoxFit.cover),
            title: Text(m.title),
            trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(m: m, path: d[i]['path'])))),
          );
        },
      ),
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

  Future _add() async {
    final u = Tg.cleanUser(_ctrl.text);
    if (u.isEmpty) return;
    try {
      final p = await Tg.fetchPage(u);
      await Store.addChannel(Channel(u, title: p.title));
      await Store.saveMovies(u, p.movies);
      _ctrl.clear();
      setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('القنوات')),
    body: ListView(padding: const EdgeInsets.all(12), children: [
      TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: '@username أو رابط القناة',
          suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _add),
        ),
      ),
      const SizedBox(height: 16),
      ...Store.channels().map((c) => ListTile(
        title: Text(c.title.isEmpty ? c.username : c.title),
        trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () { Store.delChannel(c.username); setState(() {}); }),
      )),
    ]),
  );
}

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return IconButton(
      icon: Icon(u != null ? Icons.account_circle : Icons.login),
      onPressed: () {
        if (u == null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      },
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future _google() async {
    try {
      final acc = await GoogleSignIn().signIn();
      if (acc == null) return;
      final a = await acc.authentication;
      await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: a.idToken, accessToken: a.accessToken));
      await Store.sync();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton.icon(
        onPressed: _google,
        icon: const Icon(Icons.g_mobiledata),
        label: const Text('تسجيل الدخول بـ Google'),
      ),
    ),
  );
}
