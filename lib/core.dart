import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class App {
  static final ValueNotifier<String> scope = ValueNotifier('all');
  static final ValueNotifier<int> tab = ValueNotifier(0);
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static final ValueNotifier<String> query = ValueNotifier('');
}

class Channel {
  final String username;
  String title;
  String? avatar;
  Channel(this.username, {this.title = '', this.avatar});
  Map<String, dynamic> toJson() => {'username': username, 'title': title, 'avatar': avatar};
  static Channel fromJson(Map m) => Channel(m['username'] ?? '', title: m['title'] ?? '', avatar: m['avatar']);
}

class Movie {
  final String channel;
  final int msgId;
  final String title, poster, videoUrl, description, quality, size, duration;
  final List<String> genres;
  final int date;
  final List<Map<String, String>> alts;
  late final String id, hay;

  Movie({required this.channel, required this.msgId, required this.title,
         required this.poster, required this.videoUrl, required this.description,
         required this.genres, required this.quality, required this.size,
         required this.duration, required this.date, List<Map<String, String>>? alts})
    : alts = alts ?? [],
      id = '${channel}_${msgId}' {
      hay = Search.norm('$title $description ${genres.join(' ')}');
  }

  int get year {
    final m = RegExp(r'(19|20)\d{2}').firstMatch('$title $description');
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  double get sizeMb {
    final m = RegExp(r'([\d.]+)\s*(GB|MB|TB)', caseSensitive: false).firstMatch(size);
    if (m == null) return 0;
    final v = double.tryParse(m.group(1)!) ?? 0;
    final u = m.group(2)!.toUpperCase();
    return u == 'GB' ? v * 1024 : (u == 'TB' ? v * 1024 * 1024 : v);
  }

  Map<String, dynamic> toJson() => {'channel': channel, 'msgId': msgId,
                                   'title': title, 'poster': poster, 'videoUrl': videoUrl,
                                   'description': description, 'genres': genres, 'quality': quality,
                                   'size': size, 'duration': duration, 'date': date, 'alts': alts};
  static Movie fromJson(Map m) => Movie(channel: m['channel'] ?? '',
                                    msgId: m['msgId'] ?? 0, title: m['title'] ?? '', poster: m['poster'] ?? '',
                                    videoUrl: m['videoUrl'] ?? '', description: m['description'] ?? '',
                                    genres: List<String>.from(m['genres'] ?? []), quality: m['quality'] ?? '',
                                    size: m['size'] ?? '', duration: m['duration'] ?? '', date: m['date'] ?? 0,
                                    alts: (m['alts'] as List?)?.map((e) => Map<String, String>.from(e)).toList());
}

class Search {
  static String norm(String s) => s.toLowerCase()
                                  .replaceAll(RegExp(r'[؋-ًـ]'), '')
                                  .replaceAll(RegExp(r'[أإآ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي')
                                  .replaceAll(RegExp(r'[^0-9a-z\u0600-\u06FF\s]'), ' ')
                                  .replaceAll(RegExp(r'\s+'), ' ').trim();
  static List<Movie> run(List<Movie> src, String q) {
    final nq = norm(q);
    if (nq.isEmpty) return src;
    return src.where((m) => nq.split(' ').every((t) => m.hay.contains(t))).toList();
  }
}

class Page {
  final List<Movie> movies;
  final int? before;
  final String title;
  final String? avatar;
  Page(this.movies, this.before, this.title, this.avatar);
}

/* ======== هياكل داخلية للتحليل ======== */

class _RawMsg {
  final int msgId;
  final String? video;
  final String? poster;
  final String caption;
  final String duration;
  final String size;
  final List<String> links;
  final int date;
  _RawMsg({required this.msgId, this.video, this.poster, required this.caption,
           required this.duration, required this.size, required this.links, required this.date});
}

class _LinkedVideo {
  final String url;
  final String size;
  final String duration;
  _LinkedVideo(this.url, this.size, this.duration);
}

/* ======== محلل تليجرام (يدعم كل أنماط النشر) ======== */

class Tg {
  static final Dio _dio = Dio(BaseOptions(headers: {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept':
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp/*/*;q=0.8',
    'Accept-Language':'en-US,en;q=0.9,ar;q=0.8',
  }, receiveTimeout:const Duration(seconds:20), followRedirects:true));

  static Future<String> _fetchHtml(String url) async {
    try {
      final s = (await _dio.get(url)).data.toString();
      if (s.contains('data-post="')) return s;
    } catch (_) {}
    try {
      final w = await _webviewHtml(url);
      if (w.isNotEmpty) return w;
    } catch (_) {}
    return '';
  }

  static Future<String> _webviewHtml(String url) async {
    final completer = Completer<String>();
    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      onLoadStop: (controller, _) async {
        try {
          final html = await controller.evaluateJavascript(source: "document.documentElement.outerHTML");
          if (!completer.isCompleted) completer.complete(html?.toString() ?? '');
        } catch (_) {
          if (!completer.isCompleted) completer.complete('');
        }
      },
    );
    await headless.run();
    final html = await completer.future.timeout(const Duration(seconds: 15), onTimeout: () => '');
    await headless.dispose();
    return html;
  }

  static String cleanUser(String s) {
    final m = RegExp(r'(?:t\.me/|@)?([A-Za-z0-9_]{4,})').firstMatch(s.trim());
    return m?.group(1) ?? '';
  }

  static String _un(String s) => s
      .replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&nbsp;', ' ');

  static String _strip(String s) => _un(s
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim());

  static String? _videoOf(String part) {
    var v = RegExp(r'<video[^>]*src="([^"]+)"').firstMatch(part)?.group(1);
    if (v == null || v.isEmpty) v = RegExp(r"<video[^>]*src='([^']+)'").firstMatch(part)?.group(1);
    if (v == null || v.isEmpty) v = RegExp(r'<source[^>]*src="([^"]+)"').firstMatch(part)?.group(1);
    if (v == null || v.isEmpty) v = RegExp(r'''https?://[^"<>\s]+\.mp4[^"<>\s]*''').firstMatch(part)?.group(0);
    return (v == null || v.isEmpty) ? null : _un(v);
  }

  static String? _posterOf(String part) {
    var p = RegExp(r"background-image:url\('([^']+)'").firstMatch(part)?.group(1) ?? '';
    if (p.isEmpty) p = RegExp(r'<img[^>]*src="([^"]+)"').firstMatch(part)?.group(1) ?? '';
    if (p.startsWith('//')) p = 'https:$p';
    return p.isEmpty ? null : _un(p);
  }

  static String _durationOf(String part) {
    var d = RegExp(r'duration="([^"]+)"').firstMatch(part)?.group(1) ?? '';
    if (d.isEmpty) d = RegExp(r'video_duration[^>]*>([^<]+)<').firstMatch(part)?.group(1)?.trim() ?? '';
    return d;
  }

  static String _sizeOf(String part) =>
      RegExp(r'video_size[^>]*>([^<]+)<').firstMatch(part)?.group(1)?.trim() ?? '';

  static List<String> _linksOf(String part) =>
      RegExp(r'href="(https?://t\.me/[^"]+)"').allMatches(part).map((m) => _un(m.group(1)!)).toList();

  static String _qualityOf(String cap) {
    final m = RegExp(r'(2160p|1080p|720p|480p|360p|4k|bluray|web-?dl)', caseSensitive: false).firstMatch(cap);
    if (m == null) return '';
    var q = m.group(1)!.toUpperCase();
    if (q == '4K') q = '2160P';
    return q;
  }

  static bool _isMetaCaption(String cap) {
    final c = cap.trim();
    if (c.length < 4) return false;
    if (RegExp(r'^(2160p|1080p|720p|480p|360p|4k)$', caseSensitive: false).hasMatch(c)) return false;
    if (RegExp(r'^[\d.,]+\s*(GB|MB|TB)$', caseSensitive: false).hasMatch(c)) return false;
    if (RegExp(r'^\d+$').hasMatch(c)) return false;
    return true;
  }

  static String _titleOf(String cap) {
    final lines = cap.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    for (final l in lines) {
      if (!l.startsWith('#') && !l.startsWith('http') && l.length > 2) return l;
    }
    return lines.isEmpty ? '' : lines.first;
  }

  static List<String> _genresOf(String cap) {
    final g = <String>{};
    for (final m in RegExp(r'#([^\s#]+)').allMatches(cap)) {
      final t = m.group(1)!.replaceAll(RegExp(r'[_\-]'), ' ');
      if (t.length >= 2 && t.length <= 12) g.add(t);
    }
    const keys = ['رعب','horror','اكشن','أكشن','action','دراما','drama','إثارة','اثارة','thriller',
                  'جريم','crime','كوميدي','comedy','مغامرة','adventure','خيال','fantasy','غموض',
                  'mystery','رومانسي','romance','حرب','war','عائلي','family','وثائقي','انيميشن','رسوم'];
    final low = cap.toLowerCase();
    for (final k in keys) {
      if (low.contains(k)) g.add(k);
    }
    return g.take(6).toList();
  }

  static Movie _buildFrom(String channel, int msgId, _RawMsg m, String video,
      {String? fSize, String? fDuration, String? fQuality}) {
    final q = fQuality ?? (_qualityOf(m.caption).isNotEmpty ? _qualityOf(m.caption) : _qualityOf(m.caption));
    return Movie(
      channel: channel,
      msgId: msgId,
      title: _titleOf(m.caption).isEmpty ? 'فيديو $msgId' : _titleOf(m.caption),
      poster: m.poster ?? '',
      videoUrl: video,
      description: m.caption,
      genres: _genresOf(m.caption),
      quality: q,
      size: fSize ?? m.size,
      duration: fDuration ?? m.duration,
      date: m.date,
    );
  }

  /* جلب الفيديو من رابط رسالة في قناة أخرى (نمط A و C) */
  static Future<_LinkedVideo?> _fetchLinkedVideo(List<String> links) async {
    for (final link in links.take(2)) {
      String? url;
      if (link.contains('/s/')) {
        url = link;
      } else {
        final pub = RegExp(r't\.me/([A-Za-z0-9_]+)/(\d+)').firstMatch(link);
        if (pub != null) url = 'https://t.me/s/${pub.group(1)}/${pub.group(2)}';
      }
      if (url == null) continue;
      final html = await _fetchHtml(url);
      if (html.isEmpty) continue;
      final v = _videoOf(html);
      if (v != null) return _LinkedVideo(v, _sizeOf(html), _durationOf(html));
    }
    return null;
  }

  static Future<Page> fetchPage(String user, {int? before}) async {
    final html = await _fetchHtml(
      'https://t.me/s/$user${before != null ? '?before=$before' : ''}');
    final title = RegExp(r'<meta property="og:title" content="([^"]*)"').firstMatch(html)?.group(1);
    final avatar = RegExp(r'<meta property="og:image" content="([^"]*)"').firstMatch(html)?.group(1);
    final next = RegExp(r'before=(\d+)').firstMatch(html)?.group(1);

    final raw = <_RawMsg>[];
    for (final part in html.split('data-post="').skip(1)) {
      final head = RegExp(r'^([^/"\s]+)/(\d+)').firstMatch(part);
      if (head == null) continue;
      final cap = RegExp(r'message_text[^>]*>([\s\S]*?)</div>').firstMatch(part);
      final dt = RegExp(r'datetime="([^"]+)"').firstMatch(part)?.group(1);
      raw.add(_RawMsg(
        msgId: int.parse(head.group(2)!),
        video: _videoOf(part),
        poster: _posterOf(part),
        caption: cap == null ? '' : _strip(cap.group(1)!),
        duration: _durationOf(part),
        size: _sizeOf(part),
        links: _linksOf(part),
        date: DateTime.tryParse(dt ?? '')?.millisecondsSinceEpoch ?? 0,
      ));
    }

    final movies = <Movie>[];
    final seen = <String, Movie>{};
    _RawMsg? lastMeta;
    var linkBudget = 3;

    for (final m in raw) {
      final hasMeta = m.poster != null || _isMetaCaption(m.caption);

      if (m.video != null) {
        final meta = hasMeta ? m : (lastMeta ?? m);
        final key = Search.norm(_titleOf(meta.caption));
        final q = _qualityOf(m.caption);
        if (key.isNotEmpty && seen.containsKey(key)) {
          seen[key]!.alts.add({'q': q.isEmpty ? (m.size.isEmpty ? 'جودة أخرى' : m.size) : q, 'url': m.video!});
          continue;
        }
        final mv = _buildFrom(user, m.msgId, meta, m.video!,
            fQuality: q.isNotEmpty ? q : null,
            fSize: m.size.isNotEmpty ? m.size : null,
            fDuration: m.duration.isNotEmpty ? m.duration : null);
        seen[key] = mv;
        movies.add(mv);
        if (hasMeta) lastMeta = m;
      } else if (hasMeta && m.links.isNotEmpty && linkBudget > 0) {
        linkBudget--;
        final lv = await _fetchLinkedVideo(m.links);
        if (lv != null) {
          final key = Search.norm(_titleOf(m.caption));
          if (key.isEmpty || !seen.containsKey(key)) {
            final mv = _buildFrom(user, m.msgId, m, lv.url,
                fSize: lv.size.isNotEmpty ? lv.size : null,
                fDuration: lv.duration.isNotEmpty ? lv.duration : null);
            seen[key] = mv;
            movies.add(mv);
          }
        }
        lastMeta = m;
      } else if (hasMeta) {
        lastMeta = m;
      }
    }

    return Page(movies, next == null ? null : int.parse(next),
      title == null ? user : _un(title), avatar);
  }

  static Future<List<Movie>> fetchNew(String user, {int? afterMsgId}) async {
    final page = await fetchPage(user);
    return page.movies.where((m) => m.msgId > (afterMsgId ?? 0)).toList();
  }
}

/* ======== المزامنة + إشعارات الأفلام الجديدة ======== */

class Sync {
  static bool _busy = false;
  static Timer? _timer;
  static final ValueNotifier<String> status = ValueNotifier('');
  static void Function(int count, String channel)? onNewMovies;

  static void start() {
    _timer ??= Timer.periodic(const Duration(hours: 2), (_) => checkAll());
    Future.delayed(const Duration(seconds: 3), checkAll);
  }

  static Future checkAll() async {
    if (_busy) return;
    _busy = true;
    for (final c in Store.channels()) {
      status.value = 'التحقق من الجديد: ${c.title}';
      try {
        final fresh = await Tg.fetchNew(c.username, afterMsgId: Store.maxId(c.username));
        if (fresh.isNotEmpty) {
          await Store.saveMovies(c.username, fresh);
          onNewMovies?.call(fresh.length, c.title.isEmpty ? c.username : c.title);
        }
      } catch (_) {}
    }
    status.value = '';
    _busy = false;
    Store.tick.value++;
  }
}

/* ======== التخزين المحلي ======== */

class Store {
  static late Box _ch, _mv, _st;
  static final ValueNotifier<int> tick = ValueNotifier(0);

  static Future init() async {
    _ch = await Hive.openBox('channels');
    _mv = await Hive.openBox('movies');
    _st = await Hive.openBox('state');
  }

  /* ---- قيم عامة ---- */
  static String getString(String k, [String def = '']) => (_st.get(k) as String?) ?? def;
  static Future setString(String k, String v) async { await _st.put(k, v); tick.value++; }
  static bool getBool(String k) => (_st.get(k) as bool?) ?? false;
  static Future setBool(String k, bool v) async { await _st.put(k, v); tick.value++; }
  static String get locale => getString('locale', 'ar');
  static String get theme => getString('theme', 'gold');
  static String get sortMode => getString('sortMode', 'default');
  static Future setSortMode(String v) => setString('sortMode', v);

  /* ---- القنوات ---- */
  static List<Channel> channels() => ((_ch.get('list') as List?) ?? [])
      .map((e) => Channel.fromJson(Map<String, dynamic>.from(e))).toList();

  static Future addChannel(Channel c) async {
    final l = channels();
    if (l.any((e) => e.username == c.username)) return;
    l.add(c);
    await _ch.put('list', l.map((e) => e.toJson()).toList());
    tick.value++;
  }

  static Future delChannel(String u) async {
    await _ch.put('list', channels().where((e) => e.username != u).map((e) => e.toJson()).toList());
    await _mv.delete(u);
    tick.value++;
  }

  static int maxId(String u) => moviesOf(u).isEmpty ? 0 : moviesOf(u).first.msgId;

  /* ---- الأفلام ---- */
  static List<Movie> moviesOf(String u) => ((_mv.get(u) as List?) ?? [])
    .map((e) => Movie.fromJson(Map<String, dynamic>.from(e))).toList();

  static Future saveMovies(String u, List<Movie> l) async {
    final old = moviesOf(u);
    final ids = old.map((e) => e.msgId).toSet();
    final merged = [...old, ...l.where((e) => !ids.contains(e.msgId))];
    merged.sort((a, b) => b.msgId.compareTo(a.msgId));
    await _mv.put(u, merged.map((e) => e.toJson()).toList());
    tick.value++;
  }

  static List<Movie> all() => channels()
    .expand((c) => moviesOf(c.username)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  static Future clearCache() async {
    await _mv.clear();
    tick.value++;
  }

  /* ---- المفضلة / لاحقاً ---- */
  static List<Map<String, dynamic>> _list(String k) =>
      ((_st.get(k) as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

  static List<Movie> favorites() => _list('favs').map(Movie.fromJson).toList();
  static bool isFav(String id) => _list('favs').any((e) => Movie.fromJson(e).id == id);
  static Future toggleFav(Movie m) async {
    final l = _list('favs');
    if (l.any((e) => Movie.fromJson(e).id == m.id)) {
      l.removeWhere((e) => Movie.fromJson(e).id == m.id);
    } else {
      l.insert(0, m.toJson());
    }
    await _st.put('favs', l);
    tick.value++;
  }

  static List<Movie> watchLater() => _list('later').map(Movie.fromJson).toList();
  static bool isLater(String id) => _list('later').any((e) => Movie.fromJson(e).id == id);
  static Future toggleLater(Movie m) async {
    final l = _list('later');
    if (l.any((e) => Movie.fromJson(e).id == m.id)) {
      l.removeWhere((e) => Movie.fromJson(e).id == m.id);
    } else {
      l.insert(0, m.toJson());
    }
    await _st.put('later', l);
    tick.value++;
  }

  /* ---- القوائم المخصصة ---- */
  static Map<String, List<Movie>> playlists() {
    final m = (_st.get('playlists') as Map?) ?? {};
    return m.map((k, v) => MapEntry(k.toString(),
        (v as List).map((e) => Movie.fromJson(Map<String, dynamic>.from(e))).toList()));
  }

  static Future addPlaylist(String name) async {
    final m = Map<String, dynamic>.from((_st.get('playlists') as Map?) ?? {});
    m.putIfAbsent(name, () => []);
    await _st.put('playlists', m);
    tick.value++;
  }

  static Future delPlaylist(String name) async {
    final m = Map<String, dynamic>.from((_st.get('playlists') as Map?) ?? {});
    m.remove(name);
    await _st.put('playlists', m);
    tick.value++;
  }

  static List<Movie> playlistMovies(String name) => playlists()[name] ?? [];

  static Future addToPlaylist(String name, Movie m) async {
    final all = Map<String, dynamic>.from((_st.get('playlists') as Map?) ?? {});
    final l = (all[name] as List?) ?? [];
    if (!l.any((e) => Movie.fromJson(Map<String, dynamic>.from(e)).id == m.id)) {
      l.insert(0, m.toJson());
    }
    all[name] = l;
    await _st.put('playlists', all);
    tick.value++;
  }

  static bool isInPlaylist(String name, Movie m) {
    final l = playlists()[name] ?? [];
    return l.any((e) => e.id == m.id);
  }

  /* ---- السجل والتقييمات ---- */
  static List<Movie> history() => _list('history').map(Movie.fromJson).toList();

  static Future markWatched(Movie m) async {
    final l = _list('history');
    l.removeWhere((e) => Movie.fromJson(e).id == m.id);
    l.insert(0, m.toJson());
    if (l.length > 300) l.removeRange(300, l.length);
    await _st.put('history', l);
    tick.value++;
  }

  static Future markWatchedRemove(String id) async {
    final l = _list('history');
    l.removeWhere((e) => Movie.fromJson(e).id == id);
    await _st.put('history', l);
    tick.value++;
  }

  static Map<String, int> ratings() =>
      ((_st.get('ratings') as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));

  static Future rate(String id, int n) async {
    final m = Map<String, dynamic>.from((_st.get('ratings') as Map?) ?? {});
    m[id] = n;
    await _st.put('ratings', m);
    tick.value++;
  }

  /* ---- موضع التشغيل ---- */
  static int getPosition(String id) => (_st.get('pos_$id') as int?) ?? 0;
  static Future savePosition(String id, int pos) => _st.put('pos_$id', pos);

  /* ---- الإحصائيات ---- */
  static int get watchSeconds => (_st.get('watchSeconds') as int?) ?? 0;
  static Future addWatchSeconds(int s) async => _st.put('watchSeconds', watchSeconds + s);

  /* ---- التحميلات ---- */
  static Map<String, dynamic> downloads() => Map<String, dynamic>.from((_st.get('downloads') as Map?) ?? {});

  static Future addDownload(Movie m, String path) async {
    final d = downloads();
    d[m.id] = {...m.toJson(), 'path': path};
    await _st.put('downloads', d);
    tick.value++;
  }

  static Future delDownload(String id) async {
    final d = downloads();
    d.remove(id);
    await _st.put('downloads', d);
    tick.value++;
  }

  /* ---- نسخ احتياطي ---- */
  static String exportJson() => jsonEncode({
        'channels': _ch.get('list') ?? [],
        'state': _st.toMap(),
      });

  static Future importJson(String s) async {
    try {
      final m = jsonDecode(s) as Map;
      if (m['channels'] != null) await _ch.put('list', m['channels']);
      final st = (m['state'] as Map?) ?? {};
      for (final e in st.entries) {
        await _st.put(e.key, e.value);
      }
      tick.value++;
    } catch (_) {}
  }

  /* ---- دوال التوافق مع extra.dart ---- */
  static Future setPref(String k, dynamic v) async {
    if (v is bool) {
      await _st.put(k, v);
    } else {
      await _st.put(k, v.toString());
    }
    tick.value++;
  }

  static Future<String> exportAll() async => exportJson();
  static Future importAll(String s) => importJson(s);

  static Map<String, dynamic> stats() {
    final h = history();
    final totalMinutes = watchSeconds ~/ 60;
    return {
      'hours': totalMinutes ~/ 60,
      'minutes': totalMinutes,
      'movies': h.length,
      'favorites': favorites().length,
      'downloads': downloads().length,
      'channels': channels().length,
    };
  }

  static Future toggleInPlaylist(String name, Movie m) async {
    final all = Map<String, dynamic>.from((_st.get('playlists') as Map?) ?? {});
    final l = (all[name] as List?) ?? [];
    if (l.any((e) => Movie.fromJson(Map<String, dynamic>.from(e)).id == m.id)) {
      l.removeWhere((e) => Movie.fromJson(Map<String, dynamic>.from(e)).id == m.id);
    } else {
      l.insert(0, m.toJson());
    }
    all[name] = l;
    await _st.put('playlists', all);
    tick.value++;
  }
}

/* ======== مدير التحميل ======== */

class Downloader {
  static final Dio _dio = Dio();
  static final Map<String, CancelToken> _tasks = {};
  static final ValueNotifier<Map<String, double>> progress = ValueNotifier({});
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static final ValueNotifier<bool> wifiBlocked = ValueNotifier(false);
  static final Map<String, Movie> _movies = {};

  static Future<Directory> _dir() async {
    final base = await getExternalStorageDirectory();
    final dir = Directory('${base?.path ?? '.'}/TeleCinema');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static bool isActive(String id) => _tasks.containsKey(id);
  static bool isPaused(String id) => !_tasks.containsKey(id) && progress.value.containsKey(id);
  static List<String> activeIds() => _tasks.keys.toList();
  static Movie? movieOf(String id) => _movies[id];

  static Future start(Movie m) async {
    if (isActive(m.id)) return;
    if (Store.getBool('wifiOnly')) {
      final r = await Connectivity().checkConnectivity();
      if (!r.contains(ConnectivityResult.wifi)) {
        wifiBlocked.value = true;
        return;
      }
    }
    _movies[m.id] = m;
    final token = CancelToken();
    _tasks[m.id] = token;
    tick.value++;
    try {
      final name = m.title.replaceAll(RegExp(r'[^\w\u0600-\u06FF\- ]'), '').trim();
      final path = '${(await _dir()).path}/$name.mp4';
      await _dio.download(m.videoUrl, path, cancelToken: token,
        onReceiveProgress: (a, b) {
          if (b > 0) progress.value = {...progress.value, m.id: a / b};
        });
      await Store.addDownload(m, path);
    } catch (_) {}
    _tasks.remove(m.id);
    progress.value = {...progress.value}..remove(m.id);
    tick.value++;
  }

  static Future pause(String id) async {
    _tasks[id]?.cancel();
    _tasks.remove(id);
    tick.value++;
  }

  static Future resume(String id) async {
    final m = _movies[id];
    if (m != null) await start(m);
  }

  static Future cancel(String id) async {
    _tasks[id]?.cancel();
    _tasks.remove(id);
    progress.value = {...progress.value}..remove(id);
    tick.value++;
  }

  static Future deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/* ======== الفرز ======== */

class Sorter {
  static List<Movie> apply(List<Movie> src, String mode) {
    final l = List<Movie>.from(src);
    switch (mode) {
      case 'az':
        l.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'year_desc':
        l.sort((a, b) => b.year.compareTo(a.year));
        break;
      case 'year_asc':
        l.sort((a, b) => a.year.compareTo(b.year));
        break;
      case 'size_desc':
        l.sort((a, b) => b.sizeMb.compareTo(a.sizeMb));
        break;
      case 'size_asc':
        l.sort((a, b) => a.sizeMb.compareTo(b.sizeMb));
        break;
      case 'smart':
        final genreW = <String, int>{};
        final decadeW = <int, int>{};
        for (final h in Store.history()) {
          for (final g in h.genres) genreW[g] = (genreW[g] ?? 0) + 1;
          if (h.year > 0) decadeW[(h.year ~/ 10) * 10] = (decadeW[(h.year ~/ 10) * 10] ?? 0) + 1;
        }
        final rates = Store.ratings();
        double score(Movie m) {
          double s = 0;
          for (final g in m.genres) s += (genreW[g] ?? 0) * 2;
          if (m.year > 0) s += (decadeW[(m.year ~/ 10) * 10] ?? 0) * 1.5;
          s += (rates[m.id] ?? 0) * 3;
          s += m.date / 1e15;
          return s;
        }
        l.sort((a, b) => score(b).compareTo(score(a)));
        break;
      default:
        l.sort((a, b) => b.date.compareTo(a.date));
    }
    return l;
  }
}
