import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'core.dart';
import 'ui.dart';

/* ======== 🔄 تجميع الأجزاء تلقائياً (10) ======== */
class Parts {
  static final Map<String, List<Movie>> _cache = {};
  static String base(Movie m) {
    var t = m.title.replaceAll(RegExp(r'[\[\(].*?[\]\)]'), ' ');
    t = t.replaceAll(RegExp(r'(جزء|part|season)\s*\d+', caseSensitive: false), ' ');
    t = t.replaceAll(RegExp(r'\b\d{1,2}\b'), ' ');
    return Search.norm(t);
  }

  static List<Movie> group(List<Movie> src, {bool on = true}) {
    if (!on) return src;
    _cache.clear();
    final byBase = <String, List<Movie>>{};
    for (final m in src) byBase.putIfAbsent(base(m), () => []).add(m);
    final seen = <String>{};
    final out = <Movie>[];
    for (final m in src) {
      final k = base(m);
      if (seen.contains(k)) continue;
      seen.add(k);
      final l = byBase[k]!..sort((a, b) => a.title.length.compareTo(b.title.length));
      if (l.length > 1) _cache[l.first.id] = l;
      out.add(l.first);
    }
    return out;
  }

  static List<Movie> partsOf(Movie m) => _cache[m.id] ?? [];
}

/* ======== 📊 تحليل الذوق (12) ======== */
class Taste {
  static int _dur(String s) {
    final p = s.split(':');
    try {
      if (p.length == 3) return int.parse(p[0]) * 60 + int.parse(p[1]);
      if (p.length == 2) return int.parse(p[0]);
    } catch (_) {}
    return 0;
  }

  static Map<String, dynamic> analyze() {
    final h = Store.history();
    final g = <String, int>{}, d = <int, int>{}, q = <String, int>{};
    var ds = 0, dn = 0;
    for (final m in h) {
      for (final x in m.genres) g[x] = (g[x] ?? 0) + 1;
      if (m.year > 0) d[(m.year ~/ 10) * 10] = (d[(m.year ~/ 10) * 10] ?? 0) + 1;
      final x = _dur(m.duration);
      if (x > 0) { ds += x; dn++; }
      if (m.quality.isNotEmpty) q[m.quality] = (q[m.quality] ?? 0) + 1;
    }
    String top(Map<dynamic, int> m) => m.isEmpty ? '—' : (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key.toString();
    return {'genre': top(g), 'decade': top(d), 'dur': dn == 0 ? '—' : '${ds ~/ dn}', 'quality': top(q), 'total': h.length};
  }
}

class TasteScreen extends StatelessWidget {
  const TasteScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Taste.analyze();
    return Scaffold(appBar: AppBar(title: const Text('ذوقي السينمائي 🧬')),
        body: (t['total'] as int) == 0
            ? const Center(child: Text('شاهد أفلاماً أولاً لتحليل ذوقك!', style: TextStyle(color: Colors.grey)))
            : ListView(padding: const EdgeInsets.all(16), children: [
                _row('❤️ النوع المفضل', '${t['genre']}'),
                _row('📅 العقد المفضل', '${t['decade']}'),
                _row('⏱️ متوسط المدة', '${t['dur']} دقيقة'),
                _row('🎯 الجودة المفضلة', '${t['quality']}'),
                _row('🎬 أفلام شاهدتها', '${t['total']}'),
              ]));
  }

  Widget _row(String l, String v) => Card(color: const Color(0xFF151B23), margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(dense: true, title: Text(l, style: const TextStyle(fontSize: 13)),
          trailing: Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accent))));
}

/* ======== 📅 تقويم المشاهدة (16) ======== */
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final byDay = <String, List<Movie>>{};
    for (final m in Store.history()) {
      final k = DateTime.fromMillisecondsSinceEpoch(m.date).toString().substring(0, 10);
      byDay.putIfAbsent(k, () => []).add(m);
    }
    final days = DateTime(now.year, now.month + 1, 0).day;
    return Scaffold(appBar: AppBar(title: const Text('تقويم المشاهدة 📅')),
        body: GridView.builder(padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: days, itemBuilder: (_, i) {
          final d = DateTime(now.year, now.month, i + 1).toString().substring(0, 10);
          final l = byDay[d] ?? [];
          return GestureDetector(
              onTap: l.isEmpty ? null : () => showDialog(context: context, builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF151B23), title: Text('أفلام يوم ${i + 1}'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: l.map((m) => ListTile(dense: true,
                      title: Text(m.title, style: const TextStyle(fontSize: 12)),
                      onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(m: m))); })).toList()))),
              child: Container(margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: l.isNotEmpty ? AppTheme.accent.withOpacity(0.5) : const Color(0xFF151B23), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: l.isNotEmpty ? Colors.black : Colors.grey)))));
        }));
  }
}

/* ======== 📈 ملخص شهري + رسم بياني (22+24) ======== */
class MonthlyScreen extends StatelessWidget {
  const MonthlyScreen({super.key});
  bool _sameMonth(int ms, DateTime now) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return d.year == now.year && d.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final h = Store.history().where((m) => _sameMonth(m.date, now)).toList();
    final secs = (Store.stats()['seconds'] as int?) ?? 0;
    final days = <int>[];
    final labels = <String>[];
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final k = d.toString().substring(0, 10);
      days.add(Store.history().where((m) => DateTime.fromMillisecondsSinceEpoch(m.date).toString().substring(0, 10) == k).length);
      labels.add('${d.day}');
    }
    final mx = days.reduce(max).clamp(1, 999);
    return Scaffold(appBar: AppBar(title: const Text('ملخص الشهر 📈')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            _card('${h.length}', 'أفلام هذا الشهر'),
            const SizedBox(width: 10),
            _card('${(secs / 3600).toStringAsFixed(1)}', 'ساعات إجمالية'),
          ]),
          const SizedBox(height: 24),
          const Text('آخر 7 أيام', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(height: 150, child: Row(children: List.generate(7, (i) => Expanded(child: Column(children: [
            Expanded(child: Align(alignment: Alignment.bottomCenter,
                child: Container(width: 18, height: 130 * days[i] / mx,
                    decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(6))))),
            const SizedBox(height: 4),
            Text(labels[i], style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ]))))),
        ]));
  }

  Widget _card(String v, String l) => Expanded(child: Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF151B23), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accent)),
        const SizedBox(height: 4),
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ])));
}

/* ======== 🗂️ تصفح حسب القناة (17) ======== */
class ChannelsBrowse extends StatelessWidget {
  const ChannelsBrowse({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('القنوات 🗂️')),
      body: ListView(children: Store.channels().map((c) {
        final l = Store.moviesOf(c.username);
        return ListTile(
            leading: CircleAvatar(child: Text('${l.length}', style: const TextStyle(fontSize: 12))),
            title: Text(c.title.isEmpty ? c.username : c.title, style: const TextStyle(fontSize: 14)),
            subtitle: Text('${l.length} فيلم', style: const TextStyle(fontSize: 11)),
            onTap: () { App.scope.value = c.username; App.tab.value = 0; Navigator.pop(context); });
      }).toList()));
}

/* ======== 🎬 ماراثون ذكي (11) ======== */
class Marathon {
  static void dialog(BuildContext context, Movie seed) {
    final similar = [seed, ...Store.all().where((m) => m.id != seed.id && m.genres.any(seed.genres.contains)).take(4)];
    showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF151B23),
        title: Text('ماراثون: ${seed.title} 🎬'),
        content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true,
            children: similar.map((m) => ListTile(dense: true,
                leading: const Icon(Icons.movie, size: 18),
                title: Text(m.title, style: const TextStyle(fontSize: 12)),
                trailing: IconButton(icon: Icon(Icons.play_arrow, color: AppTheme.accent),
                    onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(title: m.title, url: m.videoUrl, movie: m))); }))).toList()))));
  }
}

/* ======== 📸 لقطة اليوم (54) ======== */
class ShotGame extends StatefulWidget {
  const ShotGame({super.key});
  @override
  State<ShotGame> createState() => _ShotGameState();
}

class _ShotGameState extends State<ShotGame> {
  Movie? _m;
  List<Movie> _opts = [];
  Alignment _al = Alignment.center;
  int _score = 0;

  @override
  void initState() { super.initState(); _next(); }

  void _next() {
    final all = Store.all().where((m) => m.poster.isNotEmpty).toList();
    if (all.isEmpty) return;
    final m = all[Random().nextInt(all.length)];
    final others = (List<Movie>.from(all)..shuffle()).where((e) => e.id != m.id).take(3).toList();
    setState(() {
      _m = m;
      _opts = [...others, m]..shuffle();
      _al = Alignment(Random().nextDouble() * 2 - 1, Random().nextDouble() * 2 - 1);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('لقطة اليوم 📸 النقاط: $_score')),
      body: _m == null
          ? const Center(child: Text('لا توجد أفلام بعد', style: TextStyle(color: Colors.grey)))
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('خمّن الفيلم من اللقطة:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: SizedBox(height: 220, width: double.infinity,
                      child: FittedBox(fit: BoxFit.cover, alignment: _al, clipBehavior: Clip.hardEdge,
                          child: SizedBox(height: 400, width: 300, child: CachedNetworkImage(imageUrl: _m!.poster, fit: BoxFit.cover)))))),
              const SizedBox(height: 16),
              ..._opts.map((o) => Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                      onPressed: () { if (o.id == _m!.id) _score++; _next(); },
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF151B23), foregroundColor: Colors.white),
                      child: Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis)))),
            ]));
}

/* ======== 🖼️ معرض البوسترات (31) ======== */
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final List<Movie> _l = Store.favorites().isNotEmpty ? Store.favorites() : Store.all().take(30).toList();
  int _i = 0;

  Future _save() async {
    final m = _l[_i];
    final dir = await getExternalStorageDirectory();
    final p = '${dir!.path}/poster_${m.msgId}.jpg';
    await Dio().download(m.poster, p);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حُفظ: $p')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text('معرض البوسترات 🖼️ ${_l.isEmpty ? 0 : _i + 1}/${_l.length}'),
          actions: [IconButton(icon: const Icon(Icons.download), onPressed: _l.isEmpty ? null : _save)]),
      body: _l.isEmpty
          ? const Center(child: Text('فارغ', style: TextStyle(color: Colors.grey)))
          : PageView.builder(itemCount: _l.length, onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => InteractiveViewer(minScale: 1, maxScale: 4,
                  child: Center(child: CachedNetworkImage(imageUrl: _l[i].poster, fit: BoxFit.contain)))));
}

/* ======== 📤📥 تصدير/استيراد (36+38) ======== */
class Exporter {
  static Future<String> _dir() async => (await getExternalStorageDirectory())!.path;

  static Future<String> history() async {
    final sb = StringBuffer('🎬 سجل مشاهدتي — تلي سينما\n\n');
    for (final m in Store.history()) {
      sb.writeln('• ${m.title}  [${m.quality}]  ${DateTime.fromMillisecondsSinceEpoch(m.date).toString().substring(0, 10)}');
    }
    final p = '${await _dir()}/my_history.txt';
    await File(p).writeAsString(sb.toString());
    return p;
  }

  static Future<String> playlists() async {
    final data = {for (final n in Store.playlists().keys) n: Store.playlistMovies(n).map((e) => e.toJson()).toList()};
    final p = '${await _dir()}/playlists.json';
    await File(p).writeAsString(jsonEncode(data));
    return p;
  }

  static Future importPlaylists(String text) async {
    final data = jsonDecode(text) as Map<String, dynamic>;
    for (final e in data.entries) {
      final exist = Store.playlistMovies(e.key).map((m) => m.id).toSet();
      for (final mj in (e.value as List)) {
        final m = Movie.fromJson(Map<String, dynamic>.from(mj));
        if (!exist.contains(m.id)) await Store.toggleInPlaylist(e.key, m);
      }
    }
  }

  static void importDialog(BuildContext context) {
    final c = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF151B23),
        title: const Text('📥 استيراد القوائم'),
        content: TextField(controller: c, maxLines: 6, decoration: const InputDecoration(hintText: 'الصق JSON هنا')),
        actions: [FilledButton(onPressed: () async { try { await importPlaylists(c.text); } catch (_) {} if (context.mounted) Navigator.pop(context); }, child: const Text('استيراد'))]));
  }
}

/* ======== 👥 الحسابات المتعددة (42) ======== */
class Profiles {
  static List<String> all() => List<String>.from(Store.prefs()['profiles'] ?? ['الرئيسي']);
  static String get current => Store.getString('profile', 'الرئيسي');
  static Future switchTo(String n) => Store.setString('profile', n);

  static Future addDialog(BuildContext context) async {
    final c = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF151B23),
        title: const Text('حساب جديد 👤'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'الاسم')),
        actions: [FilledButton(onPressed: () async {
          if (c.text.trim().isNotEmpty) {
            final l = all();
            if (!l.contains(c.text.trim())) { l.add(c.text.trim()); await Store.setPref('profiles', l); }
            await switchTo(c.text.trim());
          }
          if (context.mounted) Navigator.pop(context);
        }, child: const Text('إضافة'))]));
  }

  static Future setPinDialog(BuildContext context) async {
    final c = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF151B23),
        title: const Text('🔐 رمز القبو'),
        content: TextField(controller: c, obscureText: true, decoration: const InputDecoration(hintText: 'رمز جديد (فارغ = تعطيل)')),
        actions: [FilledButton(onPressed: () async { await Store.setString('vaultPin', c.text.trim()); Vault.unlocked = false; Store.tick.value++; if (context.mounted) Navigator.pop(context); }, child: const Text('حفظ'))]));
  }

  static Future vaultChannelsDialog(BuildContext context) async {
    await showDialog(context: context, builder: (_) => ValueListenableBuilder<int>(valueListenable: Store.tick,
        builder: (_, __, ___) => AlertDialog(backgroundColor: const Color(0xFF151B23),
            title: const Text('📦 إخفاء قنوات'),
            content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true,
                children: Store.channels().map((c) {
                  final hid = Store.vaultChannels().contains(c.username);
                  return ListTile(dense: true,
                      title: Text(c.title.isEmpty ? c.username : c.title, style: const TextStyle(fontSize: 13)),
                      trailing: Icon(hid ? Icons.visibility_off : Icons.visibility, color: hid ? AppTheme.accent : Colors.grey),
                      onTap: () => Store.toggleVaultChannel(c.username));
                }).toList()))));
  }
}

/* ======== 📦 القبو السري (43) ======== */
class Vault {
  static bool get enabled => Store.getString('vaultPin', '') != '';
  static bool unlocked = false;

  static bool hidden(Movie m) => enabled && !unlocked &&
      (Store.vaultMovies().contains(m.id) || Store.vaultChannels().contains(m.channel));

  static Future<bool> ask(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF151B23),
        title: const Text('🔐 أدخل رمز القبو'),
        content: TextField(controller: c, obscureText: true),
        actions: [FilledButton(onPressed: () => Navigator.pop(context, c.text == Store.getString('vaultPin', '')), child: const Text('فتح'))]));
    if (ok == true) { unlocked = true; Store.tick.value++; }
    return ok == true;
  }

  static Future quickHide(BuildContext context, Movie m) async {
    await Store.toggleVaultMovie(m.id);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Store.vaultMovies().contains(m.id) ? '📦 أُخفي في القبو' : 'أُخرج من القبو')));
  }
}

/* ======== 📺 تشغيل خارجي / Cast (5) ======== */
class CastTv {
  static Future open(BuildContext context, Movie m) async {
    try {
      final ok = await const MethodChannel('tele_cinema/device').invokeMethod<bool>('openExternal', {'url': m.videoUrl});
      if (ok != true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مشغل خارجي')));
    } catch (_) {}
  }
}

/* ======== 🎬 TMDB إضافي: طاقم + حقائق (46+47) ======== */
class TmdbX {
  static Future<Map<String, dynamic>?> details(int id) async {
    try {
      final r = await Dio().get('https://api.themoviedb.org/3/movie/$id',
          queryParameters: {'api_key': Tmdb.apiKey, 'language': 'ar-SA', 'append_to_response': 'credits'});
      return Map<String, dynamic>.from(r.data);
    } catch (_) { return null; }
  }

  static List<Map<String, dynamic>> castOf(Map d) =>
      List<Map<String, dynamic>>.from(((d['credits']?['cast'] as List?) ?? []).take(8).map((e) => Map<String, dynamic>.from(e)));

  static List<String> factsOf(Map d, Movie m) {
    final f = <String>[];
    final ot = (d['original_title'] ?? '').toString();
    if (ot.isNotEmpty && Search.norm(ot) != Search.norm(m.title)) f.add('الاسم الأصلي: $ot');
    final cs = (d['production_countries'] as List? ?? []);
    if (cs.isNotEmpty) f.add('إنتاج: ${cs.map((e) => e['name']).take(2).join('، ')}');
    final rt = (d['runtime'] as int? ?? 0);
    if (rt > 0) f.add('المدة الرسمية: $rt د');
    final bud = (d['budget'] as int? ?? 0);
    if (bud > 0) f.add('الميزانية: ${(bud / 1000000).round()}M\$');
    return f;
  }
}

/* ======== 🌌 الخلفية الحية (26) ======== */
Widget liveWallBg() {
  final h = Store.history();
  final url = h.isNotEmpty ? h.first.poster : '';
  if (url.isEmpty) return const SizedBox.shrink();
  return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox.shrink());
}
