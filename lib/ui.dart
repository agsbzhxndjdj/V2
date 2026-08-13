import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core.dart';

/* ======== الهيكل الرئيسي ======== */
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: App.tab,
      builder: (ctx, tab, _) => Scaffold(
            body: const IndexedStack(children: [
              HomePage(),
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
        const AccountMenu(),
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

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.all(6),
        child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PlayerScreen(m: m))),
          child: Stack(fit: StackFit.expand, children: [
            Container(
                color: const Color(0xFF1B2430),
                child: const Center(
                    child: Icon(Icons.movie_filter,
                        size: 42, color: Colors.amber))),
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
                      style:
                          const TextStyle(fontSize: 9, color: Colors.white70))),
            Positioned(
                top: 4,
                left: 4,
                child: ValueListenableBuilder<Map<String, double>>(
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
                            onPressed: () => Downloader.start(m)))),
          ]),
        ),
      );
}

/* ======== مشغل البث عبر السيرفر ======== */
class PlayerScreen extends StatefulWidget {
  final Movie m;
  const PlayerScreen({super.key, required this.m});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  ChewieController? _cc;
  VideoPlayerController? _vp;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    Store.markWatched(widget.m);
    _init();
  }

  Future _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.m.videoUrl));
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _vp = c;
        _cc = ChewieController(
            videoPlayerController: c,
            aspectRatio: c.value.aspectRatio,
            autoPlay: false,
            allowFullScreen: true);
      });
    } catch (_) {
      if (mounted) setState(() => _err = true);
    }
  }

  @override
  void dispose() {
    _cc?.dispose();
    _vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.m.title)),
        body: _err
            ? const Center(
                child: Text('تعذر تشغيل الفيديو',
                    style: TextStyle(color: Colors.grey)))
            : _cc == null
                ? const Center(child: CircularProgressIndicator())
                : Center(child: Chewie(controller: _cc!)),
      );
}

/* ======== مشغل محلي ======== */
class LocalPlayerScreen extends StatefulWidget {
  final String title, path;
  const LocalPlayerScreen({super.key, required this.title, required this.path});
  @override
  State<LocalPlayerScreen> createState() => _LocalPlayerScreenState();
}

class _LocalPlayerScreenState extends State<LocalPlayerScreen> {
  ChewieController? _cc;
  VideoPlayerController? _vp;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future _init() async {
    try {
      final c = VideoPlayerController.file(File(widget.path));
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _vp = c;
        _cc = ChewieController(
            videoPlayerController: c,
            aspectRatio: c.value.aspectRatio,
            autoPlay: false,
            allowFullScreen: true);
      });
    } catch (_) {
      if (mounted) setState(() => _err = true);
    }
  }

  @override
  void dispose() {
    _cc?.dispose();
    _vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: _err
            ? const Center(child: Text('الملف غير موجود',
                style: TextStyle(color: Colors.grey)))
            : _cc == null
                ? const Center(child: CircularProgressIndicator())
                : Center(child: Chewie(controller: _cc!)),
      );
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
                                builder: (_) => PlayerScreen(m: h[i]))),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: () =>
                                Store.markWatchedRemove(h[i].id)))));
      });
}

/* ======== تحميلاتي ======== */
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        final items = Store.downloads().entries.toList();
        return Scaffold(
            appBar: AppBar(title: const Text('تحميلاتي')),
            body: items.isEmpty
                ? const Center(
                    child: Text('لا توجد تحميلات',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = items[i];
                      final m =
                          Movie.fromJson(Map<String, dynamic>.from(e.value));
                      final path = e.value['path']?.toString() ?? '';
                      return ListTile(
                          leading: const CircleAvatar(
                              child: Icon(Icons.download_done, size: 20)),
                          title: Text(m.title,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(m.size.isEmpty ? path : m.size,
                              style: const TextStyle(fontSize: 10)),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => LocalPlayerScreen(
                                      title: m.title, path: path))),
                          trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 20),
                              onPressed: () async {
                                await Downloader.deleteFile(path);
                                await Store.delDownload(e.key);
                              }));
                    }));
      });
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
        Store.sync();
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
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
                        backgroundImage:
                            c.avatar != null ? NetworkImage(c.avatar!) : null,
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

/* ======== الحساب ======== */
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return IconButton(
        icon: Icon(u != null ? Icons.manage_accounts : Icons.login_outlined),
        onPressed: () {
          if (u == null) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
            return;
          }
          showModalBottomSheet(
              context: context,
              builder: (_) => SafeArea(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                    ListTile(
                        leading: CircleAvatar(
                            child: Text(u.displayName?.isNotEmpty == true
                                ? u.displayName![0]
                                : 'ح')),
                        title: Text(u.displayName ?? ''),
                        subtitle: Text(u.email ?? '')),
                    ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('تسجيل الخروج'),
                        onTap: () async {
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
      await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(
              idToken: a.idToken, accessToken: a.accessToken));
      await Store.sync();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: const Color(0xFF151B23),
                borderRadius: BorderRadius.circular(28)),
            child:
                const Icon(Icons.movie_filter, size: 70, color: Colors.amber)),
        const SizedBox(height: 18),
        const Text('تلي سينما',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.amber)),
        const SizedBox(height: 6),
        Text('أفلام قنواتك بواجهة تليق بها',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        const SizedBox(height: 40),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: FilledButton.icon(
                onPressed: () => _google(context),
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('تسجيل الدخول عبر Google'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))))),
        const SizedBox(height: 8),
        TextButton(
            onPressed: () async {
              await Store.setGuest(true);
              App.tick.value++;
            },
            child: const Text('المتابعة كضيف')),
      ])));
}
