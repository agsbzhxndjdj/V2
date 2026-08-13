import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

/* ======== البحث الذكي ======== */
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

/* ======== قارئ القنوات العامة ======== */
class Page {
  final List<Movie> movies;
  final int? before;
  final String title;
  final String? avatar;
  Page(this.movies, this.before, this.title, this.avatar);
}

class Tg {
  static final Dio _dio = Dio(BaseOptions(headers: {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
  }, receiveTimeout: const Duration(seconds: 25)));

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

  static Future<Page> fetchPage(String user, {int? before}) async {
    final html = (await _dio
            .get('https://t.me/s/$user${before != null ? '?before=$before' : ''}'))
        .data
        .toString();
    final title = RegExp(r'<meta property="og:title" content="([^"]*)"')
        .firstMatch(html)?.group(1);
    final avatar = RegExp(r'<meta property="og:image" content="([^"]*)"')
        .firstMatch(html)?.group(1);
    final next = RegExp(r'before=(\d+)').firstMatch(html)?.group(1);

    final movies = <Movie>[];
    for (final part in html.split('data-post="').skip(1)) {
      final head = RegExp(r'^([^/"]+)/(\d+)').firstMatch(part);
      if (head == null) continue;
      final video = RegExp(r'<video[^>]*src="([^"]+)"').firstMatch(part)?.group(1);
      if (video == null || video.isEmpty) continue;
      var poster =
          RegExp(r"background-image:url\('([^']+)'").firstMatch(part)?.group(1) ?? '';
      if (poster.startsWith('//')) poster = 'https:$poster';
      var duration = RegExp(r'duration="([^"]+)"').firstMatch(part)?.group(1) ?? '';
      if (duration.isEmpty) {
        duration = RegExp(r'video_duration[^>]*>([^<]+)<')
                .firstMatch(part)?.group(1)?.trim() ??
            '';
      }
      final size =
          RegExp(r'video_size[^>]*>([^<]+)<').firstMatch(part)?.group(1)?.trim() ?? '';
      final cap = RegExp(r'message_text[^>]*>([\s\S]*?)</div>').firstMatch(part);
      final dt = RegExp(r'datetime="([^"]+)"').firstMatch(part)?.group(1);
      movies.add(_build(head.group(1)!, int.parse(head.group(2)!), poster, video,
          cap == null ? '' : _strip(cap.group(1)!),
          DateTime.tryParse(dt ?? '')?.millisecondsSinceEpoch ?? 0, duration, size));
    }
    return Page(movies, next == null ? null : int.parse(next),
        title == null ? user : _un(title), avatar);
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

/* ======== التخزين + المزامنة ======== */
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
  static Future saveMovies(String u, List<Movie> l) =>
      _mv.put(u, l.map((e) => e.toJson()).toList());
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

/* ======== التحميلات ======== */
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