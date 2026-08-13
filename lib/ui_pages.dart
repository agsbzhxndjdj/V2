import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'ui_detail.dart';
import 'core.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        final h = Store.history();
        return Scaffold(
          appBar: AppBar(title: const Text('شاهدتها'), actions: [
            if (h.isNotEmpty)
              IconButton(icon: const Icon(Icons.delete_sweep), onPressed: () async {
                for (final m in List.of(h)) {
                  await Store.markWatchedRemove(m.id);
                }
              }),
          ]),
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
                    subtitle: Text(fmtDate(h[i].date), style: const TextStyle(fontSize: 10)),
                    trailing: const Icon(Icons.chevron_left, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => DetailScreen(m: h[i]))),
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
                        title: Text('جارٍ التحميل… ${(pr[id]! * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(icon: const Icon(Icons.close),
                            onPressed: () => Downloader.cancel(id)))),
                    ...done.values.map((e) {
                      final m = Movie.fromJson(Map<String, dynamic>.from(e));
                      return ListTile(
                        leading: ClipRRect(borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: m.poster,
                                width: 52, height: 74, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(width: 52,
                                    color: const Color(0xFF151B23),
                                    child: const Icon(Icons.movie, size: 22, color: Colors.grey)))),
                        title: Text(m.title, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(m.size, style: const TextStyle(fontSize: 10)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.play_arrow, color: Colors.amber),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => PlayerScreen(m: m, path: e['path'])))),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                await Downloader.deleteFile(e['path']);
                                await Store.delDownload(m.id);
                              }),
                        ]),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DetailScreen(m: m))));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر العثور عليها — تأكد أنها قناة عامة ولها يوزر')));
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
          TextField(controller: _ctrl,
            decoration: InputDecoration(
              hintText: 'الصق رابط القناة أو @اليوزر أو المعرف…',
              prefixIcon: const Icon(Icons.add_link),
              suffixIcon: _busy
                  ? const Padding(padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(icon: const Icon(Icons.add_circle, color: Colors.amber),
                      onPressed: _add),
              filled: true, fillColor: const Color(0xFF151B23),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none)),
          const SizedBox(height: 16),
          ListTile(
            dense: true,
            leading: const CircleAvatar(child: Icon(Icons.video_library)),
            title: const Text('الكل — جميع القنوات', style: TextStyle(fontSize: 14)),
            trailing: App.scope.value == 'all'
                ? const Icon(Icons.check_circle, color: Colors.amber, size: 18) : null,
            onTap: () { App.scope.value = 'all'; App.tab.value = 0; }),
          const Divider(),
          ...Store.channels().map((c) => ListTile(
                leading: CircleAvatar(
                    backgroundImage: c.avatar != null ? NetworkImage(c.avatar!) : null,
                    child: c.avatar == null ? const Icon(Icons.rss_feed) : null),
                title: Text(c.title.isEmpty ? c.username : c.title,
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text('@${c.username} • ${Store.moviesOf(c.username).length} فيلم',
                    style: const TextStyle(fontSize: 11)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (App.scope.value == c.username)
                    const Icon(Icons.check_circle, color: Colors.amber, size: 18),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => Store.delChannel(c.username)),
                ]),
                onTap: () { App.scope.value = c.username; App.tab.value = 0; },
              )),
        ]),
      ));
          }
