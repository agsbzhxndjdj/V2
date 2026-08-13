import 'package:flutter/material.dart';
import 'ui_cards.dart';
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

  import 'package:flutter/material.dart';
import 'ui_cards.dart';
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

  @override
  Widget build(BuildContext context) {
    final movies = Search.run(_source, _search.text);
    return Scaffold(
      appBar: AppBar(title: const Text('تلي سينما'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        const AccountMenu(),
      ]),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: GridView.builder(
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
