import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'ui_detail.dart';
import 'ui_account.dart';
import 'core.dart';

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

  List<Movie> get _source =>
      App.scope.value == 'all' ? Store.all() : Store.moviesOf(App.scope.value);

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
        : Store.channels().where((c) => c.username == App.scope.value).toList();
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

  List<String> _topGenres(List<Movie> src) {
    final count = <String, int>{};
    for (final m in src) {
      for (final g in m.genres) {
        count[g] = (count[g] ?? 0) + 1;
      }
    }
    return (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(12).map((e) => e.key).toList();
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
              FilledButton.icon(
                  onPressed: () => App.tab.value = 3,
                  icon: const Icon(Icons.add), label: const Text('إضافة قناة')),
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
                      suffixIcon: _search.text.isEmpty ? null :
                          IconButton(icon: const Icon(Icons.clear, size: 18),
                              onPressed: () { App.query.value = ''; _search.clear(); setState(() {}); }),
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
                        ...Store.channels().map((c) =>
                            _chip(c.title.isEmpty ? c.username : c.title, scope == c.username,
                                () => App.scope.value = c.username)),
                      ])),
                )),
                if (genres.isNotEmpty)
                  SliverToBoxAdapter(child: SizedBox(height: 40,
                    child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal, children: genres
                          .map((g) => _chip(g, _search.text == g, () {
                                App.query.value = _search.text == g ? '' : g;
                                _syncQuery();
                              }, small: true)).toList()))),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                        (_, i) => MovieCard(m: movies[i]), childCount: movies.length),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, childAspectRatio: 0.58,
                        mainAxisSpacing: 8, crossAxisSpacing: 8),
                  ),
                ),
                SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Center(child: _more
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : TextButton(onPressed: _loadMore,
                            child: const Text('تحميل المزيد من الأفلام'))))),
              ])),
      floatingActionButton: _busy ? const CircularProgressIndicator() : null,
    );
  }

  Widget _chip(String t, bool sel, VoidCallback on, {bool small = false}) => Padding(
      padding: EdgeInsets.only(right: small ? 6 : 8),
      child: FilterChip(
          label: Text(t, style: TextStyle(fontSize: small ? 11 : 13)),
          selected: sel, onSelected: (_) => on()));
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
      child: ClipRRect(borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          m.poster.isNotEmpty
              ? CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.cover, memCacheWidth: 300,
                  placeholder: (_, __) => Container(color: const Color(0xFF151B23)),
                  errorWidget: (_, __, ___) => _ph())
              : _ph(),
          Container(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(.88)]))),
          Positioned(top: 4, left: 4, child: Row(children: [
            if (watched) const Icon(Icons.check_circle, size: 15, color: Colors.green),
            if (dl) const Icon(Icons.download_done, size: 15, color: Colors.amber),
          ])),
          if (m.quality.isNotEmpty)
            Positioned(top: 4, right: 4, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                child: Text(m.quality, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)))),
          Positioned(bottom: 6, left: 6, right: 6, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            if (m.size.isNotEmpty)
              Text(m.size, style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
          ])),
        ])),
    );
  }

  Widget _ph() => Container(color: const Color(0xFF151B23),
      child: const Icon(Icons.movie_outlined, size: 40, color: Colors.grey));
}
