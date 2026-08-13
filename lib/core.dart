import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  Map<String, dynamic> toJson() =>
      {'username': username, 'title': title, 'avatar': avatar};
  static Channel fromJson(Map m) =>
      Channel(m['username'] ?? '', title: m['title'] ?? '', avatar: m['avatar']);
}

class Movie {
  final String channel;
  final int msgId;
  final String title, poster, videoUrl, description, quality, size, duration;
  final List<String> genres;
  final int date;
  late final String id, hay;

  Movie({required this.channel, required this.msgId, required this.title,
      required this.poster, required this.videoUrl, required this.description,
      required this.genres, required this.quality, required this.size,
      required this.duration, required this.date})
      : id = '${channel}_$msgId' {
    hay = Search.norm('$title $description ${genres.join(' ')}');
  }

  Map<String, dynamic> toJson() => {'channel': channel, 'msgId': msgId,
      'title': title, 'poster': poster, 'videoUrl': videoUrl,
      'description': description, 'genres': genres, 'quality': quality,
      'size': size, 'duration': duration, 'date': date};

  static Movie fromJson(Map m) => Movie(channel: m['channel'] ?? '',
      msgId: m['msgId'] ?? 0, title: m['title'] ?? '', poster: m['poster'] ?? '',
      videoUrl: m['videoUrl'] ?? '', description: m['description'] ?? '',
      genres: List<String>.from(m['genres'] ?? []), quality: m['quality'] ?? '',
      size: m['size'] ?? '', duration: m['duration'] ?? '', date: m['date'] ?? 0);
}

class Search {
  static String norm(String s) => s.toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '')
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

class Tg {
  static final Dio _dio = Dio(BaseOptions(
      receiveTimeout: const Duration(seconds: 15),
      connectTimeout: const Duration(seconds: 10),
      followRedirects: true,
      validateStatus: (s) => s != null && s < 500));

  static String cleanUser(String input) {
    var s = input.trim()
        .replaceAll(RegExp(r'https?://(t\.me|telegram\.me)/'), '')
        .replaceFirst(RegExp(r'^[sS]/'), '');
    s = s.split('?').first.split('/').first;
    return s.replaceFirst('@', '');
  }

  static String _un(String s) => s
      .replaceAll('<br>', '\n').replaceAll('<br/>', '\n')
      .replaceAll('&amp;', '&').replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>');

  static String _strip(String s) => _un(s).replaceAll(RegExp(r'<[^>]+>'), '');

  static Future<String?> _fetchEmbed(String user, int msgId) async {
    try {
      final r = await _dio.get('https://t.me/$user/$msgId?embed=1&mode=tme',
          options: Options(headers: {'User-Agent': 'Mozilla/5.0', 'Accept': '*/*'}));
      if (r.statusCode == 200) {
        final data = r.data.toString();
        if (data.contains('tgme_widget_message') || data.contains('tgme_widget')) {
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<int?> _findLatestMsgId(String user) async {
    int low = 1;
    int high = 1000000;
    int? lastValid;
    while (low <= high) {
      final mid = low + ((high - low) ~/ 2);
      final exists = await _fetchEmbed(user, mid) != null;
      if (exists) {
        lastValid = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
      if (high - low < 10) break;
    }
    return lastValid;
  }

  static Future<({String title, String? avatar})> _getChannelInfo(String user) async {
    try {
      final r = await Dio(BaseOptions(
              receiveTimeout: const Duration(seconds: 10), followRedirects: true))
          .get('https://t.me/$user',
              options: Options(headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Accept': 'text/html',
              }));
      final html = r.data.toString();
      final title = RegExp(r'<meta property="og:title" content="([^"]*)"')
              .firstMatch(html)?.group(1) ??
          user;
      final avatar = RegExp(r'<meta property="og:image" content="([^"]*)"')
          .firstMatch(html)?.group(1);
      return (title: _un(title), avatar: avatar);
    } catch (_) {
      return (title: user, avatar: null);
    }
  }

  static Future<Page> fetchPage(String user, {int? before}) async {
    final info = await _getChannelInfo(user);
    int? startId = before;
    if (startId == null) {
      startId = await _findLatestMsgId(user);
      if (startId == null) return Page([], null, info.title, info.avatar);
    }
    final results = <int, String>{};
    final tasks = <Future>[];
    for (var i = 0; i < 30; i++) {
      final id = startId - i;
      if (id < 1) break;
      tasks.add(() async {
        final html = await _fetchEmbed(user, id);
        if (html != null) results[id] = html;
      }());
    }
    await Future.wait(tasks);
    final movies = <Movie>[];
    for (final id in results.keys.toList()..sort((a, b) => b.compareTo(a))) {
      final movie = _parseEmbed(user, id, results[id]!);
      if (movie != null) movies.add(movie);
    }
    final nextBefore = movies.isEmpty ? null : (movies.last.msgId - 1);
    return Page(movies, nextBefore, info.title, info.avatar);
  }

  /// يجلب كل الأفلام الأحدث من afterMsgId (0 = كل شيء)
  static Future<List<Movie>> fetchNew(String user, {required int afterMsgId}) async {
    final out = <Movie>[];
    int? before;
    while (true) {
      final p = await fetchPage(user, before: before);
      if (p.movies.isEmpty) break;
      var stop = false;
      for (final m in p.movies) {
        if (m.msgId <= afterMsgId) {
          stop = true;
          break;
        }
        out.add(m);
      }
      if (stop || p.before == null) break;
      before = p.before;
      if (out.length > 5000) break;
    }
    return out;
  }

  static Movie? _parseEmbed(String channel, int msgId, String html) {
    var video = RegExp(r'data-video="([^"]+)"').firstMatch(html)?.group(1) ??
        RegExp(r'<video[^>]*src="([^"]+)"').firstMatch(html)?.group(1) ??
        RegExp(r'<source[^>]*src="([^"]+)"').firstMatch(html)?.group(1) ??
        RegExp(r'''href="([^"]+\.mp4[^"]*)"''').firstMatch(html)?.group(1);
    if (video == null || video.isEmpty) {
      video = RegExp(r'''https?://[^"'<>\s]+\.mp4[^"'<>\s]*''').firstMatch(html)?.group(0);
    }
    if (video == null || video.isEmpty) return null;
    if (video.startsWith('//')) video = 'https:$video';

    var poster = RegExp(r'''data-poster="([^"]+)"''').firstMatch(html)?.group(1) ??
        RegExp(r'''background-image:\s*url\(['"]?([^'")\s]+)['"]?\)''',
                caseSensitive: false)
            .firstMatch(html)?.group(1) ??
        RegExp(r'''<img[^>]*src="([^"]+)"''').firstMatch(html)?.group(1) ??
        '';
    if (poster.startsWith('//')) poster = 'https:$poster';

    var duration = RegExp(r'data-duration="([^"]+)"').firstMatch(html)?.group(1) ??
        RegExp(r'duration[^>]*>([^<]+)<').firstMatch(html)?.group(1)?.trim() ?? '';
    var size = RegExp(r'video_size[^>]*>([^<]+)<').firstMatch(html)?.group(1)?.trim() ?? '';

    final capMatch = RegExp(
            r'<div[^>]*class="[^"]*tgme_widget_message_text[^"]*"[^>]*>([\s\S]*?)</div>',
            caseSensitive: false)
        .firstMatch(html);
    final caption = capMatch != null ? _strip(capMatch.group(1) ?? '') : '';

    final dt = RegExp(r'<time[^>]*datetime="([^"]+)"').firstMatch(html)?.group(1);
    final date = DateTime.tryParse(dt ?? '')?.millisecondsSinceEpoch ?? 0;

    return _build(channel, msgId, poster, video, caption, date, duration, size);
  }

  static Movie _build(String ch, int mid, String poster, String video,
      String caption, int date, String dur, String size) {
    final lines =
        caption.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final title = lines.isNotEmpty ? lines.first : 'فيديو #$mid';
    var quality = '';
    var genres = <String>[];
    final desc = <String>[];
    for (final l in lines.skip(1)) {
      final q =
          RegExp(r'(2160p|1080p|720p|480p|4k)', caseSensitive: false).firstMatch(l);
      if (q != null && quality.isEmpty) {
        quality = q.group(1)!.toUpperCase();
        continue;
      }
      if (genres.isEmpty && l.contains('|') && l.length < 60) {
        genres = l
            .split(RegExp(r'[|،]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        continue;
      }
      desc.add(l);
    }
    return Movie(channel: ch, msgId: mid, title: title, poster: poster,
        videoUrl: video, description: desc.join('\n'), genres: genres,
        quality: quality, size: size, duration: dur, date: date);
  }
}

/* ======== المزامنة التلقائية ======== */
class Sync {
  static bool _busy = false;
  static Timer? _timer;
  static final ValueNotifier<String> status = ValueNotifier('');

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
        if (fresh.isNotEmpty) await Store.saveMovies(c.username, fresh);
      } catch (_) {}
    }
    status.value = '';
    _busy = false;
    Store.tick.value++;
  }

  static Future loadAll(String user) async {
    while (_busy) {
      await Future.delayed(const Duration(seconds: 1));
    }
    _busy = true;
    status.value = 'تحميل كل أفلام القناة…';
    try {
      final all = await Tg.fetchNew(user, afterMsgId: 0);
      if (all.isNotEmpty) await Store.saveMovies(user, all);
    } catch (_) {}
    status.value = '';
    _busy = false;
    Store.tick.value++;
  }
}

class Store {
  static late Box _ch, _mv, _st;
  static final ValueNotifier<int> tick = ValueNotifier(0);

  static Future init() async {
    _ch = await Hive.openBox('channels');
    _mv = await Hive.openBox('movies');
    _st = await Hive.openBox('state');
  }

  static bool isGuest() => _st.get('guest', defaultValue: false);
  static Future setGuest(bool v) => _st.put('guest', v);

  static List<Channel> channels() => _ch.values
      .map((e) => Channel.fromJson(Map<String, dynamic>.from(e))).toList();
  static Future addChannel(Channel c) async {
    await _ch.put(c.username, c.toJson());
    tick.value++;
  }
  static Future delChannel(String u) async {
    await _ch.delete(u);
    await _mv.delete(u);
    tick.value++;
  }

  static List<Movie> moviesOf(String u) => ((_mv.get(u) as List?) ?? [])
      .map((e) => Movie.fromJson(Map<String, dynamic>.from(e))).toList();

  static int maxId(String u) {
    var m = 0;
    for (final e in moviesOf(u)) {
      if (e.msgId > m) m = e.msgId;
    }
    return m;
  }

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

  static List<Movie> history() => ((_st.get('history') as List?) ?? [])
      .map((e) => Movie.fromJson(Map<String, dynamic>.from(e))).toList();
  static Future markWatched(Movie m) async {
    final h = history()..removeWhere((e) => e.id == m.id);
    h.insert(0, m);
    await _st.put('history', h.map((e) => e.toJson()).toList());
    tick.value++;
  }
  static Future markWatchedRemove(String id) async {
    final h = history()..removeWhere((e) => e.id == id);
    await _st.put('history', h.map((e) => e.toJson()).toList());
    tick.value++;
  }

  static Map<String, dynamic> downloads() =>
      Map<String, dynamic>.from(_st.get('downloads') ?? {});
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

  static Future sync() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (snap.exists) {
      final d = snap.data()!;
      final localCh = channels().map((e) => e.username).toSet();
      for (final c in (d['channels'] as List? ?? [])) {
        final ch = Channel.fromJson(Map<String, dynamic>.from(c));
        if (!localCh.contains(ch.username)) await addChannel(ch);
      }
      final merged = history();
      final ids = merged.map((e) => e.id).toSet();
      for (final h in (d['history'] as List? ?? [])) {
        final m = Movie.fromJson(Map<String, dynamic>.from(h));
        if (!ids.contains(m.id)) merged.add(m);
      }
      await _st.put('history', merged.map((e) => e.toJson()).toList());
      tick.value++;
    }
    await ref.set({
      'name': u.displayName ?? '',
      'email': u.email ?? '',
      'channels': channels().map((e) => e.toJson()).toList(),
      'history': history().map((e) => e.toJson()).toList(),
      'updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class Downloader {
  static final Dio _dio = Dio();
  static final Map<String, CancelToken> _tasks = {};
  static final ValueNotifier<Map<String, double>> progress = ValueNotifier({});

  static Future<String> _dir() async {
    final base = await getExternalStorageDirectory();
    final dir = Directory('${base!.path}/Movies');
    if (!await dir.exists()) await dir.create();
    return dir.path;
  }

  static bool isActive(String id) => _tasks.containsKey(id);

  static Future start(Movie m) async {
    if (isActive(m.id)) return;
    final token = CancelToken();
    _tasks[m.id] = token;
    try {
      final name = m.title.replaceAll(RegExp(r'[^\w\u0600-\u06FF\- ]'), '').trim();
      final path = '${await _dir()}/$name.mp4';
      await _dio.download(m.videoUrl, path, cancelToken: token,
          onReceiveProgress: (a, b) {
        if (b > 0) progress.value = {...progress.value, m.id: a / b};
      });
      await Store.addDownload(m, path);
    } catch (_) {}
    _tasks.remove(m.id);
    progress.value = {...progress.value}..remove(m.id);
  }

  static void cancel(String id) {
    _tasks.remove(id)?.cancel();
    progress.value = {...progress.value}..remove(id);
  }

  static Future deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
