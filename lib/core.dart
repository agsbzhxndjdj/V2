import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

/* ======== إعدادات الخادم ======== */
class ApiConfig {
  static const String baseUrl = 'http://13.49.41.150:5000';
  static const String apiKey =
      '9fded672447abe47324249048e9b3ee8a3472a6564e613dbfc50ff159655667a';
}

/* ======== تنقّل مشترك ======== */
class App {
  static final ValueNotifier<String> scope = ValueNotifier('all');
  static final ValueNotifier<int> tab = ValueNotifier(0);
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static final ValueNotifier<String> query = ValueNotifier('');
}

/* ======== النماذج ======== */
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

  Movie(
      {required this.channel,
      required this.msgId,
      required this.title,
      required this.poster,
      required this.videoUrl,
      required this.description,
      required this.genres,
      required this.quality,
      required this.size,
      required this.duration,
      required this.date})
      : id = '${channel}_$msgId' {
    hay = Search.norm('$title $description ${genres.join(' ')}');
  }

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'msgId': msgId,
        'title': title,
        'poster': poster,
        'videoUrl': videoUrl,
        'description': description,
        'genres': genres,
        'quality': quality,
        'size': size,
        'duration': duration,
        'date': date
      };

  static Movie fromJson(Map m) => Movie(
      channel: m['channel'] ?? '',
      msgId: m['msgId'] ?? 0,
      title: m['title'] ?? '',
      poster: m['poster'] ?? '',
      videoUrl: m['videoUrl'] ?? '',
      description: m['description'] ?? '',
      genres: List<String>.from(m['genres'] ?? []),
      quality: m['quality'] ?? '',
      size: m['size'] ?? '',
      duration: m['duration'] ?? '',
      date: m['date'] ?? 0);
}

/* ======== البحث الذكي ======== */
class Search {
  static String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '')
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[^0-9a-z\u0600-\u06FF\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<Movie> run(List<Movie> src, String q) {
    final nq = norm(q);
    if (nq.isEmpty) return src;
    return src
        .where((m) => nq.split(' ').every((t) => m.hay.contains(t)))
        .toList();
  }
}

/* ======== قارئ القنوات ======== */
class Page {
  final List<Movie> movies;
  final int? before;
  final String title;
  final String? avatar;
  Page(this.movies, this.before, this.title, this.avatar);
}

class Tg {
  static final Dio _dio = Dio(BaseOptions(
      receiveTimeout: const Duration(seconds: 60),
      connectTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'}));

  static String cleanUser(String input) {
    var s = input
        .trim()
        .replaceAll(RegExp(r'https?://(t\.me|telegram\.me)/'), '')
        .replaceFirst(RegExp(r'^[sS]/'), '');
    s = s.split('?').first.split('/').first;
    return s.replaceFirst('@', '');
  }

  static String streamUrl(String user, int msgId) =>
      '${ApiConfig.baseUrl}/stream/$user/$msgId?key=${ApiConfig.apiKey}';

  static String posterUrl(String user, int msgId) =>
      '${ApiConfig.baseUrl}/poster/$user/$msgId?key=${ApiConfig.apiKey}';

  static Future<Page> fetchPage(String user, {int? before}) async {
    if (before != null) return Page([], null, user, null);
    final res = await _dio.get('${ApiConfig.baseUrl}/channel/$user',
        queryParameters: {'key': ApiConfig.apiKey, 'limit': 200});
    final data = res.data;
    if (data is! Map) throw Exception('استجابة غير صالحة من الخادم');
    if (data['error'] != null) throw Exception(data['error'].toString());
    final title = (data['title'] ?? user).toString();
    final avatar = data['avatar']?.toString();
    final movies = <Movie>[];
    for (final item in (data['messages'] as List? ?? [])) {
      if (item is! Map) continue;
      if (item['has_video'] != true) continue;
      final mid =
          (item['msg_id'] is num) ? (item['msg_id'] as num).toInt() : 0;
      if (mid == 0) continue;
      final caption = (item['text'] ?? '').toString();
      final date =
          ((item['date'] is num) ? (item['date'] as num).toInt() : 0) * 1000;
      movies.add(_build(user, mid, caption, date,
          (item['duration'] ?? '').toString(),
          (item['size'] ?? '').toString()));
    }
    return Page(movies, null, title, avatar);
  }

  static Movie _build(String ch, int mid, String caption, int date,
      String dur, String size) {
    final lines = caption
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final title = lines.isNotEmpty ? lines.first : 'فيديو #$mid';
    var quality = '';
    var genres = <String>[];
    final desc = <String>[];
    for (final l in lines.skip(1)) {
      final q = RegExp(r'(2160p|1080p|720p|480p|4k)', caseSensitive: false)
          .firstMatch(l);
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
    return Movie(
        channel: ch,
        msgId: mid,
        title: title,
        poster: posterUrl(ch, mid),
        videoUrl: streamUrl(ch, mid),
        description: desc.join('\n'),
        genres: genres,
        quality: quality,
        size: size,
        duration: dur,
        date: date);
  }
}

/* ======== التخزين + الإعدادات ======== */
class Store {
  static late Box _ch, _mv, _st;
  static final ValueNotifier<int> tick = ValueNotifier(0);

  static Future init() async {
    _ch = await Hive.openBox('channels');
    _mv = await Hive.openBox('movies');
    _st = await Hive.openBox('state');
  }

  /* ---- الإعدادات العامة ---- */
  static Map<String, dynamic> prefs() =>
      Map<String, dynamic>.from(_st.get('prefs') ?? {});
  static Future setPref(String k, dynamic v) async {
    final p = prefs();
    p[k] = v;
    await _st.put('prefs', p);
    tick.value++;
  }

  static String get locale => (prefs()['locale'] as String?) ?? 'ar';
  static String get theme => (prefs()['theme'] as String?) ?? 'gold';
  static bool getBool(String k, [bool d = false]) =>
      (prefs()[k] as bool?) ?? d;

  static List<Channel> channels() => _ch.values
      .map((e) => Channel.fromJson(Map<String, dynamic>.from(e)))
      .toList();

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
      .map((e) => Movie.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  static Future saveMovies(String u, List<Movie> l) =>
      _mv.put(u, l.map((e) => e.toJson()).toList());

  static List<Movie> all() => channels()
      .expand((c) => moviesOf(c.username))
      .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /* ======== المفضلة ======== */
  static List<Movie> favorites() => ((_st.get('favorites') as List?) ?? [])
      .map((e) => Movie.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  static bool isFav(String id) => favorites().any((e) => e.id == id);

  static Future toggleFav(Movie m) async {
    final f = favorites();
    if (f.any((e) => e.id == m.id)) {
      f.removeWhere((e) => e.id == m.id);
    } else {
      f.insert(0, m);
    }
    await _st.put('favorites', f.map((e) => e.toJson()).toList());
    tick.value++;
  }

  /* ======== سأشاهده لاحقاً ======== */
  static List<Movie> watchLater() => ((_st.get('watchLater') as List?) ?? [])
      .map((e) => Movie.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  static bool isLater(String id) => watchLater().any((e) => e.id == id);

  static Future toggleLater(Movie m) async {
    final f = watchLater();
    if (f.any((e) => e.id == m.id)) {
      f.removeWhere((e) => e.id == m.id);
    } else {
      f.insert(0, m);
    }
    await _st.put('watchLater', f.map((e) => e.toJson()).toList());
    tick.value++;
  }

  /* ======== التقييم ======== */
  static Map<String, int> ratings() =>
      Map<String, int>.from(_st.get('ratings') ?? {});
  static Future rate(String id, int stars) async {
    final r = ratings();
    if (stars <= 0) {
      r.remove(id);
    } else {
      r[id] = stars;
    }
    await _st.put('ratings', r);
    tick.value++;
  }

  /* ======== سجل المشاهدة ======== */
  static List<Movie> history() => ((_st.get('history') as List?) ?? [])
      .map((e) => Movie.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  static Future markWatched(Movie m) async {
    if (getBool('incognito')) return;
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

  /* ======== موضع المشاهدة ======== */
  static Map<String, int> positions() =>
      Map<String, int>.from(_st.get('positions') ?? {});

  static Future savePosition(String movieId, int seconds) async {
    final p = positions();
    if (seconds > 10) {
      p[movieId] = seconds;
      await _st.put('positions', p);
    }
  }

  static int getPosition(String movieId) => positions()[movieId] ?? 0;

  /* ======== القوائم المخصصة ======== */
  static Map<String, dynamic> playlists() =>
      Map<String, dynamic>.from(_st.get('playlists') ?? {});
  static Future addPlaylist(String name) async {
    final p = playlists();
    p[name] = <dynamic>[];
    await _st.put('playlists', p);
    tick.value++;
  }

  static Future delPlaylist(String name) async {
    final p = playlists();
    p.remove(name);
    await _st.put('playlists', p);
    tick.value++;
  }

  static List<Movie> playlistMovies(String name) =>
      ((playlists()[name] as List?) ?? [])
          .map((e) => Movie.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  static Future toggleInPlaylist(String name, Movie m) async {
    final p = playlists();
    final l = playlistMovies(name);
    if (l.any((e) => e.id == m.id)) {
      l.removeWhere((e) => e.id == m.id);
    } else {
      l.insert(0, m);
    }
    p[name] = l.map((e) => e.toJson()).toList();
    await _st.put('playlists', p);
    tick.value++;
  }

  /* ======== الإحصائيات ======== */
  static Map<String, dynamic> stats() =>
      Map<String, dynamic>.from(_st.get('stats') ?? {});
  static Future addWatchSeconds(int s) async {
    final st = stats();
    st['seconds'] = ((st['seconds'] as int?) ?? 0) + s;
    st['count'] = ((st['count'] as int?) ?? 0) + 1;
    await _st.put('stats', st);
  }

  /* ======== النسخ الاحتياطي ======== */
  static Future<Map<String, dynamic>> exportAll() async => {
        'channels': _ch.toMap(),
        'movies': _mv.toMap(),
        'state': _st.toMap(),
      };

  static Future importAll(Map<String, dynamic> data) async {
    if (data['channels'] is Map) {
      await _ch.clear();
      await _ch.putAll(Map<String, dynamic>.from(data['channels']));
    }
    if (data['state'] is Map) {
      await _st.clear();
      await _st.putAll(Map<String, dynamic>.from(data['state']));
    }
    tick.value++;
  }

  /* ======== التحميلات المكتملة ======== */
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
}

/* ======== مدير التحميلات ======== */
class Downloader {
  static final Dio _dio = Dio();
  static final Map<String, CancelToken> _tokens = {};
  static final Map<String, bool> _paused = {};
  static final Map<String, bool> _cancelled = {};
  static final Map<String, int> _received = {};
  static final Map<String, Movie> _movies = {};
  static final ValueNotifier<Map<String, double>> progress = ValueNotifier({});
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static final ValueNotifier<bool> wifiBlocked = ValueNotifier(false);

  static bool isActive(String id) => _tokens.containsKey(id);

  static bool isPaused(String id) =>
      _paused[id] == true && !_tokens.containsKey(id);

  static Movie? movieOf(String id) => _movies[id];

  static List<String> activeIds() => _movies.keys.toList();

  static Future<String> _dir() async {
    final base = await getExternalStorageDirectory();
    final dir = Directory('${base!.path}/Movies');
    if (!await dir.exists()) await dir.create();
    return dir.path;
  }

  static Future deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<bool> start(Movie m) async {
    final id = m.id;
    if (isActive(id)) return false;
    if (isPaused(id)) {
      await resume(id);
      return true;
    }
    if (Store.getBool('wifiOnly')) {
      final r = await Connectivity().checkConnectivity();
      if (r != ConnectivityResult.wifi) {
        wifiBlocked.value = true;
        return false;
      }
    }
    _movies[id] = m;
    _paused[id] = false;
    _cancelled[id] = false;
    _received[id] = 0;
    progress.value = {...progress.value, id: 0.0};
    tick.value++;
    await _run(m, 0);
    return true;
  }

  static Future _run(Movie m, int offset) async {
    final id = m.id;
    final token = CancelToken();
    _tokens[id] = token;
    tick.value++;
    String? path;
    IOSink? sink;
    try {
      final name =
          m.title.replaceAll(RegExp(r'[^\w\u0600-\u06FF\- ]'), '').trim();
      path = '${await _dir()}/$name.mp4';
      final file = File(path);
      if (offset > 0 && !await file.exists()) offset = 0;
      if (offset == 0 && await file.exists()) await file.delete();
      sink =
          file.openWrite(mode: offset > 0 ? FileMode.append : FileMode.write);
      final resp = await _dio.get<ResponseBody>(
        m.videoUrl,
        options: Options(
            responseType: ResponseType.stream,
            headers: offset > 0 ? {'Range': 'bytes=$offset-'} : null),
        cancelToken: token,
      );
      final len =
          int.tryParse(resp.headers.value('content-length') ?? '0') ?? 0;
      final total = offset + len;
      int received = offset;
      await for (final chunk in resp.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        _received[id] = received;
        if (total > 0) {
          final pct = received / total;
          final last = progress.value[id] ?? 0;
          if ((pct - last).abs() > 0.005 || pct >= 1) {
            progress.value = {...progress.value, id: pct};
          }
        }
      }
      await sink.close();
      await Store.addDownload(m, path);
      _removeAll(id);
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      if (_cancelled[id] == true) {
        if (path != null) await deleteFile(path);
        _removeAll(id);
      } else if (_paused[id] == true) {
        _tokens.remove(id);
        tick.value++;
      } else {
        if (path != null) await deleteFile(path);
        _removeAll(id);
      }
    }
  }

  static void pause(String id) {
    if (!isActive(id)) return;
    _paused[id] = true;
    _tokens.remove(id)?.cancel();
    tick.value++;
  }

  static Future resume(String id) async {
    final m = _movies[id];
    if (m == null || isActive(id)) return;
    _paused[id] = false;
    _cancelled[id] = false;
    tick.value++;
    await _run(m, _received[id] ?? 0);
  }

  static void cancel(String id) {
    _cancelled[id] = true;
    _paused[id] = false;
    _tokens.remove(id)?.cancel();
    if (!isActive(id)) _removeAll(id);
    tick.value++;
  }

  static void _removeAll(String id) {
    _tokens.remove(id);
    _paused.remove(id);
    _cancelled.remove(id);
    _received.remove(id);
    _movies.remove(id);
    progress.value = {...progress.value}..remove(id);
    tick.value++;
  }
}
