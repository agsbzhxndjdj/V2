import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'core.dart';
import 'lang.dart';
import 'ui.dart';

/* ======== 🔄 تجميع السلاسل والأجزاء تلقائياً ======== */
class Parts {
  static final Map<String, List<Movie>> _cache = {};

  static const List<String> franchises = [
    'spiderman',
    'piratesofthecaribbean',
    'after',
    'conjuring',
    'maze runner',
    'transformers',
    'fast furious',
    'captain america',
    'bad boys',
    'john wick',
    'harry potter',
    'mission impossible',
    'avatar',
    'alien',
    'terminator',
    'jurassic',
    'deadpool',
    'wolverine',
    'batman',
    'avengers',
    'iron man',
  ];

  static String base(Movie m) {
    var t = m.title.toLowerCase();
    t = t.replaceAll(RegExp(r'[\[\(].*?[\]\)]'), ' ');
    t = t.split(':').first;
    t = t.replaceAll(RegExp(r'(19|20)\d{2}'), ' ');
    t = t.replaceAll(
        RegExp(
            r'(2160p|1080p|720p|480p|360p|4k|uhd|hdr|bluray|web-?dl|hdtv|dvdrip|brrip|fhd)',
            caseSensitive: false),
        ' ');
    t = t.replaceAll(RegExp(r'\d+'), ' ');
    t = t.replaceAll(
        RegExp(r'(جزء|part|season|episode|ii|iii|iv|v)\b', caseSensitive: false),
        ' ');
    t = Search.norm(t);
    t = t.replaceAll(RegExp(r'^the\s+'), '');
    t = t.replaceAll(RegExp(r'spider\s*-?\s*man'), 'spiderman');
    t = t.replaceAll(
        RegExp(r'pirates\s+of\s+the\s+caribbean'), 'piratesofthecaribbean');
    t = t.replaceAll(RegExp(r'fast\s+and\s+furious'), 'fast furious');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    for (final f in franchises) {
      if (t == f || t.startsWith('$f ')) return f;
    }
    return t;
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
      final l = byBase[k]!
        ..sort((a, b) => a.title.length.compareTo(b.title.length));
      if (l.length > 1) _cache[l.first.id] = l;
      out.add(l.first);
    }
    return out;
  }

  static List<Movie> partsOf(Movie m) => _cache[m.id] ?? [];
}

/* ======== 📊 تحليل الذوق ======== */
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

/* ======== 📅 تقويم المشاهدة ======== */
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

/* ======== 📈 ملخص شهري ======== */
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
    final mx = days.isEmpty ? 1 : days.reduce(max).clamp(1, 999);
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

/* ======== 🗂️ تصفح حسب القناة ======== */
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

/* ======== 🎬 ماراثون ذكي ======== */
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

/* ======== 📸 لقطة اليوم ======== */
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('لقطة اليوم 📸 النقاط: $_score')),
      body: _m == null
          ? const Center(child: Text('لا توجد أفلام بعد', style: TextStyle(color: Colors.grey)))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('خمّن الفيلم من اللقطة:', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: _al,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  height: 400,
                  width: 300,
                  child: CachedNetworkImage(imageUrl: _m!.poster, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final o in _opts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton(
                onPressed: () {
                  if (o.id == _m!.id) _score++;
                  _next();
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF151B23), foregroundColor: Colors.white),
                child: Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
      ),
    );
  }
}

/* ======== 🖼️ معرض البوسترات ======== */
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

/* ======== 📤 تصدير/استيراد ======== */
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

  static Future<int> importPlaylists(String text) async {
    final data = jsonDecode(text);
    if (data is! Map) throw const FormatException('ملف غير صالح');
    int count = 0;
    for (final e in data.entries) {
      if (e.value is! List) continue;
      final name = e.key.toString();
      final exist = Store.playlistMovies(name).map((m) => m.id).toSet();
      for (final mj in (e.value as List)) {
        if (mj is! Map) continue;
        final m = Movie.fromJson(Map<String, dynamic>.from(mj));
        if (!exist.contains(m.id)) {
          await Store.toggleInPlaylist(name, m);
          count++;
        }
      }
    }
    return count;
  }

  static Future<void> importDialog(BuildContext context) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;

      String text = '';
      if (f.bytes != null) {
        text = utf8.decode(f.bytes!);
      } else if (f.path != null) {
        text = await File(f.path!).readAsString();
      }

      if (text.trim().isEmpty) {
        _toast(context, 'الملف فارغ');
        return;
      }

      final n = await importPlaylists(text);
      if (context.mounted) _toast(context, 'تم الاستيراد ✅ ($n فيلم)');
    } catch (_) {
      if (context.mounted) {
        _toast(context, 'فشل الاستيراد — تأكد أن الملف JSON صالح');
      }
    }
  }

  static void _toast(BuildContext context, String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
}

/* ======== 👥 الحسابات المتعددة ======== */
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
    await showDialog(
      context: context,
      builder: (_) => ValueListenableBuilder<int>(
        valueListenable: Store.tick,
        builder: (_, __, ___) => AlertDialog(
          backgroundColor: const Color(0xFF151B23),
          title: const Text('📦 إخفاء قنوات'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: Store.channels().map((c) {
                final hid = Store.vaultChannels().contains(c.username);
                return ListTile(
                  dense: true,
                  title: Text(c.title.isEmpty ? c.username : c.title, style: const TextStyle(fontSize: 13)),
                  trailing: Icon(hid ? Icons.visibility_off : Icons.visibility, color: hid ? AppTheme.accent : Colors.grey),
                  onTap: () => Store.toggleVaultChannel(c.username),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/* ======== 📦 القبو السري ======== */
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

/* ======== 📺 تشغيل خارجي / Cast ======== */
class CastTv {
  static Future open(BuildContext context, Movie m) async {
    try {
      final ok = await const MethodChannel('tele_cinema/device').invokeMethod<bool>('openExternal', {'url': m.videoUrl});
      if (ok != true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مشغل خارجي')));
    } catch (_) {}
  }
}

/* ======== 🎬 TMDB إضافي: طاقم + حقائق ======== */
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
    if (ot.isNotEmpty && Search.norm(ot) != Search.norm(m.title)) f.add('الأصل: $ot');
    final cs = (d['production_countries'] as List? ?? []);
    if (cs.isNotEmpty) f.add('إنتاج: ${cs.map((e) => e['name']).take(2).join('، ')}');
    final rt = (d['runtime'] as int? ?? 0);
    if (rt > 0) f.add('المدة الرسمية: $rt د');
    final bud = (d['budget'] as int? ?? 0);
    if (bud > 0) f.add('الميزانية: ${(bud / 1000000).round()}M\$');
    return f;
  }
}

/* ======== 🌌 الخلفية الحية ======== */
Widget liveWallBg() {
  final h = Store.history();
  final url = h.isNotEmpty ? h.first.poster : '';
  if (url.isEmpty) return const SizedBox.shrink();
  return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox.shrink());
}

/* ======== فلاتر البحث المتقدم ======== */
class Filters {
  static int yearFrom = 0, yearTo = 0, maxMin = 0;
  static String quality = '';
  static final Set<String> genres = {};
  static bool get active => yearFrom > 0 || yearTo > 0 || quality.isNotEmpty || maxMin > 0 || genres.isNotEmpty;
  static void clear() { yearFrom = 0; yearTo = 0; quality = ''; maxMin = 0; genres.clear(); }

  static int _durMin(String s) {
    final p = s.split(':');
    try {
      if (p.length == 3) return int.parse(p[0]) * 60 + int.parse(p[1]);
      if (p.length == 2) return int.parse(p[0]);
    } catch (_) {}
    return 0;
  }

  static List<Movie> apply(List<Movie> src) {
    if (!active) return src;
    return src.where((m) {
      if (yearFrom > 0 && m.year < yearFrom) return false;
      if (yearTo > 0 && m.year > yearTo) return false;
      if (quality.isNotEmpty && m.quality != quality) return false;
      if (maxMin > 0 && _durMin(m.duration) > maxMin) return false;
      if (genres.isNotEmpty && !genres.any(m.genres.contains)) return false;
      return true;
    }).toList();
  }
}

class AdvancedFilterDialog extends StatelessWidget {
  const AdvancedFilterDialog({super.key});
  @override
  Widget build(BuildContext context) => AlertDialog(
      backgroundColor: const Color(0xFF151B23),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [Icon(Icons.tune, size: 20), SizedBox(width: 8), Text('تصفية متقدمة', style: TextStyle(fontSize: 15))]),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('سنة الإصدار', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Row(children: [
          Expanded(child: _yearBtn(context, 'من', Filters.yearFrom, (v) => Filters.yearFrom = v)),
          const SizedBox(width: 8),
          Expanded(child: _yearBtn(context, 'إلى', Filters.yearTo, (v) => Filters.yearTo = v)),
        ]),
        const SizedBox(height: 12),
        const Text('الجودة', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Wrap(spacing: 6, children: ['', '1080P', '720P', '480P'].map((q) => FilterChip(
            label: Text(q.isEmpty ? 'الكل' : q, style: const TextStyle(fontSize: 11)),
            selected: Filters.quality == q,
            onSelected: (_) => Filters.quality = q)).toList()),
        const SizedBox(height: 12),
        const Text('المدة القصوى', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Wrap(spacing: 6, children: [0, 90, 120, 150].map((mn) => FilterChip(
            label: Text(mn == 0 ? 'الكل' : '$mn دقيقة', style: const TextStyle(fontSize: 11)),
            selected: Filters.maxMin == mn,
            onSelected: (_) => Filters.maxMin = mn)).toList()),
        const SizedBox(height: 12),
        const Text('الأنواع', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Wrap(spacing: 6, children: ['اكشن', 'رعب', 'دراما', 'كوميدي', 'إثارة', 'مغامرة', 'رومانسي'].map((g) => FilterChip(
            label: Text(g, style: const TextStyle(fontSize: 11)),
            selected: Filters.genres.contains(g),
            onSelected: (_) { if (Filters.genres.contains(g)) { Filters.genres.remove(g); } else { Filters.genres.add(g); } })).toList()),
      ]))),
      actions: [
        TextButton(onPressed: () { Filters.clear(); Navigator.pop(context, true); }, child: const Text('مسح')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تطبيق')),
      ]);

  Widget _yearBtn(BuildContext context, String l, int cur, Function(int) set) => OutlinedButton(
      onPressed: () async {
        final y = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF151B23),
            title: Text('اختر السنة ($l)'),
            content: Wrap(spacing: 6, children: [0, 1970, 1980, 1990, 2000, 2010, 2015, 2020, 2023, 2024, 2025, 2026].map((y) => ActionChip(label: Text(y == 0 ? 'الكل' : '$y', style: const TextStyle(fontSize: 11)), onPressed: () => Navigator.pop(ctx, y))).toList())));
        if (y != null) set(y);
      },
      child: Text(cur == 0 ? '$l: الكل' : '$l: $cur', style: const TextStyle(fontSize: 12)));
}

/* ======== اكتشاف + عجلة الحظ + مدير الوقت ======== */
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _mood = '';
  int _decade = 0;

  int _durMin(String s) {
    final p = s.split(':');
    try {
      if (p.length == 3) return int.parse(p[0]) * 60 + int.parse(p[1]);
      if (p.length == 2) return int.parse(p[0]);
    } catch (_) {}
    return 0;
  }

  List<Movie> _filtered() {
    var list = Smart.dedup(Store.all());
    if (_mood.isNotEmpty) list = list.where((m) => m.genres.join(' ').contains(_mood)).toList();
    if (_decade > 0) list = list.where((m) => m.year >= _decade && m.year < _decade + 10).toList();
    return list;
  }

  void _random(List<Movie> l) {
    if (l.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(m: l[Random().nextInt(l.length)])));
  }

  void _timeDialog(List<Movie> l) {
    showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF151B23),
        title: const Text('⏱ عندي وقت قدره…'),
        content: Wrap(spacing: 8, children: [60, 90, 120, 150].map((mn) => ActionChip(
            label: Text('$mn دقيقة', style: const TextStyle(fontSize: 12)),
            onPressed: () {
              Navigator.pop(context);
              final ok = l.where((m) => _durMin(m.duration) <= mn && _durMin(m.duration) > 0).toList();
              _random(ok.isEmpty ? l : ok);
            })).toList())));
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();
    return Scaffold(
        appBar: AppBar(title: const Text('اكتشف 🧭')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Row(children: [
            Expanded(child: _act(Icons.shuffle, 'فيلم عشوائي', () => _random(list))),
            const SizedBox(width: 8),
            Expanded(child: _act(Icons.casino, 'عجلة الحظ', () => showDialog(context: context, builder: (_) => WheelDialog(pool: list.isEmpty ? Store.all() : list)))),
            const SizedBox(width: 8),
            Expanded(child: _act(Icons.timer, 'وقتي محدود', () => _timeDialog(list))),
          ]),
          const SizedBox(height: 14),
          const Text('حسب المزاج', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: ['كوميدي', 'رعب', 'اكشن', 'دراما', 'رومانسي', 'مغامرة', 'إثارة'].map((g) => FilterChip(
              label: Text(g, style: const TextStyle(fontSize: 11)),
              selected: _mood == g,
              onSelected: (_) => setState(() => _mood = _mood == g ? '' : g))).toList()),
          const SizedBox(height: 10),
          const Text('حقب السينما 📜', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var y = 1970; y <= 2020; y += 10)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: FilterChip(
                  label: Text('الـ${y}s', style: const TextStyle(fontSize: 11)),
                  selected: _decade == y,
                  onSelected: (_) => setState(() => _decade = _decade == y ? 0 : y))),
          ])),
          const SizedBox(height: 14),
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey))))
          else
            GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.55),
                itemCount: min(60, list.length), itemBuilder: (_, i) => MovieCard(m: list[i])),
        ]));
  }

  Widget _act(IconData ic, String t, VoidCallback f) => InkWell(
      onTap: f, borderRadius: BorderRadius.circular(14),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF151B23), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.accent.withOpacity(0.3))),
          child: Column(children: [
            Icon(ic, color: AppTheme.accent, size: 26),
            const SizedBox(height: 6),
            Text(t, style: const TextStyle(fontSize: 11)),
          ])));
}

/* ======== عجلة الحظ ======== */
class WheelDialog extends StatefulWidget {
  final List<Movie> pool;
  const WheelDialog({super.key, required this.pool});
  @override
  State<WheelDialog> createState() => _WheelDialogState();
}

class _WheelDialogState extends State<WheelDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  double _target = 0;
  Movie? _pick;
  bool _spinning = false;

  @override
  void initState() { super.initState(); _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800)); }

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  void _spin() {
    if (_spinning || widget.pool.isEmpty) return;
    setState(() { _spinning = true; _pick = null; _target = 5 + Random().nextDouble() * 4; });
    _ctl.reset();
    _ctl.animateTo(1, curve: Curves.easeOutCubic).then((_) {
      if (mounted) setState(() { _spinning = false; _pick = widget.pool[Random().nextInt(widget.pool.length)]; });
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
      backgroundColor: const Color(0xFF151B23),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🎡 عجلة الحظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        AnimatedBuilder(animation: _ctl, builder: (_, __) => CustomPaint(
            size: const Size(220, 220),
            painter: _WheelPainter(_ctl.value * _target * 2 * pi))),
        const SizedBox(height: 14),
        if (_pick != null) ...[
          Text(_pick!.title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            FilledButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(m: _pick!))); }, child: const Text('شاهده 🎬')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _spin, child: const Text('لَف مرة ثانية')),
          ]),
        ] else
          FilledButton.icon(onPressed: _spinning ? null : _spin, icon: const Icon(Icons.play_arrow), label: Text(_spinning ? 'تدور…' : 'لُف العجلة!')),
      ])));
}

class _WheelPainter extends CustomPainter {
  final double rot;
  _WheelPainter(this.rot);
  static const _cols = [0xFFE5B76A, 0xFF37474F, 0xFF7E57C2, 0xFF2E7D32, 0xFFC62828, 0xFF1565C0, 0xFF6D4C41, 0xFF00838F];
  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2);
    final rad = s.width / 2;
    final seg = 2 * pi / 8;
    for (var i = 0; i < 8; i++) {
      c.drawArc(Rect.fromCircle(center: ctr, radius: rad), rot + i * seg, seg, true, Paint()..color = Color(_cols[i]));
    }
    c.drawCircle(ctr, rad * 0.15, Paint()..color = const Color(0xFF0B0F14));
    final p = Path();
    p.moveTo(s.width / 2 - 8, 0);
    p.lineTo(s.width / 2 + 8, 0);
    p.lineTo(s.width / 2, 16);
    p.close();
    c.drawPath(p, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant _WheelPainter o) => o.rot != rot;
}

/* ======== الإنجازات ======== */
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final h = Store.history();
    final favs = Store.favorites().length;
    final dls = Store.downloads().length;
    final rts = Store.ratings().length;
    final xp = h.length * 10 + rts * 5 + favs * 2 + dls * 20;
    final level = xp ~/ 100 + 1;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final horrorWeek = h.where((m) => m.date > weekAgo && m.genres.join(' ').contains('رعب')).length;
    final genresWatched = <String>{for (final m in h) ...m.genres}.length;

    final challenges = [
      {'t': 'شاهد 10 أفلام', 'c': h.length, 'g': 10},
      {'t': '5 أفلام رعب هذا الأسبوع', 'c': horrorWeek, 'g': 5},
      {'t': 'قيّم 5 أفلام', 'c': rts, 'g': 5},
      {'t': 'حمّل 3 أفلام', 'c': dls, 'g': 3},
      {'t': 'ستريك 3 أيام 🔥', 'c': Store.bestStreak, 'g': 3},
    ];
    final badges = [
      {'i': '🎬', 't': 'أول فيلم', 'on': h.length >= 1},
      {'i': '🔥', 't': 'ستريك 3 أيام', 'on': Store.bestStreak >= 3},
      {'i': '🏆', 't': '50 فيلماً', 'on': h.length >= 50},
      {'i': '⭐', 't': 'أول تقييم', 'on': rts >= 1},
      {'i': '📥', 't': 'أول تحميل', 'on': dls >= 1},
      {'i': '❤️', 't': '10 مفضلة', 'on': favs >= 10},
      {'i': '🎭', 't': 'مستكشف (5 أنواع)', 'on': genresWatched >= 5},
      {'i': '🦉', 't': 'سرّي: بصمة سينمائية', 'on': xp >= 500},
    ];
    return Scaffold(
        appBar: AppBar(title: const Text('إنجازاتي 🏆')),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          Row(children: [
            Expanded(child: _card('🔥 ${Store.streak}', 'ستريك حالي')),
            const SizedBox(width: 10),
            Expanded(child: _card('🏅 ${Store.bestStreak}', 'أفضل ستريك')),
          ]),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF151B23), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('المستوى $level', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
                  const Spacer(),
                  Text('$xp XP', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (xp % 100) / 100, minHeight: 6, valueColor: AlwaysStoppedAnimation(AppTheme.accent), backgroundColor: Colors.white12),
              ])),
          const SizedBox(height: 16),
          const Text('التحديات 🎯', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...challenges.map((c) {
            final done = (c['c'] as int) >= (c['g'] as int);
            return Card(color: const Color(0xFF151B23), margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(dense: true,
                    leading: Icon(done ? Icons.verified : Icons.lock_outline, color: done ? AppTheme.accent : Colors.grey, size: 20),
                    title: Text(c['t'] as String, style: const TextStyle(fontSize: 13)),
                    subtitle: LinearProgressIndicator(value: ((c['c'] as int) / (c['g'] as int)).clamp(0, 1), minHeight: 4, valueColor: AlwaysStoppedAnimation(AppTheme.accent), backgroundColor: Colors.white12),
                    trailing: Text('${c['c']}/${c['g']}', style: const TextStyle(fontSize: 11, color: Colors.grey))));
          }),
          const SizedBox(height: 12),
          const Text('الشارات 🏅', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.9),
              itemCount: badges.length, itemBuilder: (_, i) {
                final b = badges[i];
                return Opacity(opacity: b['on'] as bool ? 1 : 0.3,
                    child: Container(margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFF151B23), borderRadius: BorderRadius.circular(12)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(b['i'] as String, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(b['t'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9)),
                        ])));
              }),
        ]));
  }

  Widget _card(String v, String l) => Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF151B23), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent)),
        const SizedBox(height: 4),
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]));
}

/* ======== معرض البوستر ======== */
class PosterScreen extends StatelessWidget {
  final Movie m;
  const PosterScreen({super.key, required this.m});

  Future _save(BuildContext context) async {
    try {
      final dir = await getExternalStorageDirectory();
      final p = '${dir!.path}/poster_${m.msgId}.jpg';
      await Dio().download(m.poster, p);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حُفظ: $p')));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('البوستر 🖼️'), actions: [
        IconButton(icon: const Icon(Icons.download), onPressed: () => _save(context)),
      ]),
      body: InteractiveViewer(
          minScale: 0.8, maxScale: 4,
          child: Center(child: Hero(tag: 'poster_${m.id}', child: CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.contain)))));
}

/* ======== التعليقات ======== */
class CommentsSheet {
  static void show(BuildContext context, Movie m) {
    final ctrl = TextEditingController();
    showModalBottomSheet(isScrollControlled: true, backgroundColor: const Color(0xFF151B23),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        context: context, builder: (_) => Padding(padding: MediaQuery.of(context).viewInsets,
            child: ValueListenableBuilder<int>(valueListenable: Store.tick, builder: (_, __, ___) {
              final list = Store.commentsOf(m.id);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.all(12), child: Text('التعليقات (${list.length}) 💬', style: const TextStyle(fontWeight: FontWeight.bold))),
                ConstrainedBox(constraints: const BoxConstraints(maxHeight: 300),
                    child: list.isEmpty
                        ? const Padding(padding: EdgeInsets.all(20), child: Text('كن أول من يعلّق!', style: TextStyle(color: Colors.grey, fontSize: 12)))
                        : ListView.builder(itemCount: list.length, itemBuilder: (_, i) => ListTile(dense: true,
                            leading: CircleAvatar(child: Text((list[i]['user'] ?? '؟').toString().substring(0, 1))),
                            title: Text(list[i]['user'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                            subtitle: Text(list[i]['text'] ?? '', style: const TextStyle(fontSize: 12)))),
                ),
                Padding(padding: const EdgeInsets.all(8), child: Row(children: [
                  Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(hintText: 'اكتب تعليقاً…', isDense: true, filled: true, fillColor: const Color(0xFF0B0F14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                  IconButton(icon: Icon(Icons.send, color: AppTheme.accent), onPressed: () async {
                    if (ctrl.text.trim().isNotEmpty) {
                      await Store.addComment(m.id, ctrl.text.trim(), 'ضيف');
                      ctrl.clear();
                    }
                  }),
                ])),
              ]);
            })));
  }
}

/* ======== بطاقة فيلم للمشاركة ======== */
class ShareCard {
  static final GlobalKey _bk = GlobalKey();

  static Future<void> show(BuildContext context, Movie m) => showDialog(context: context,
      builder: (_) => AlertDialog(backgroundColor: const Color(0xFF151B23),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            RepaintBoundary(key: _bk, child: Container(width: 250, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF0B0F14), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.accent.withOpacity(0.6))),
                child: Column(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10),
                      child: m.poster.isNotEmpty
                          ? CachedNetworkImage(imageUrl: m.poster, width: 150, height: 210, fit: BoxFit.cover)
                          : const SizedBox(width: 150, height: 210, child: Icon(Icons.movie, size: 60))),
                  const SizedBox(height: 10),
                  Text(m.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 5),
                  Text([m.quality, if (m.year > 0) '${m.year}', m.duration].where((e) => e.isNotEmpty).join(' • '),
                      style: TextStyle(fontSize: 10, color: AppTheme.accent)),
                  const SizedBox(height: 8),
                  const Text('تلي سينما 🎬', style: TextStyle(fontSize: 9, color: Colors.grey)),
                ]))),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () => _save(context), icon: const Icon(Icons.save_alt, size: 18), label: const Text('حفظ البطاقة')),
          ])));

  static Future _save(BuildContext context) async {
    try {
      final b = _bk.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getExternalStorageDirectory();
      final f = File('${dir!.path}/card_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bytes!.buffer.asUint8List());
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حُفظت: ${f.path}')));
    } catch (_) {}
  }
}

/* ======== التحميل الذكي على WiFi ======== */
class SmartDownload {
  static Future check() async {
    if (!Store.getBool('smartDl')) return;
    try {
      final r = await Connectivity().checkConnectivity();
      if (!r.contains(ConnectivityResult.wifi)) return;
    } catch (_) { return; }
    for (final m in Store.watchLater()) {
      if (Downloader.isActive(m.id) || Store.downloads().containsKey(m.id)) continue;
      Downloader.start(m);
      break;
    }
  }
}
