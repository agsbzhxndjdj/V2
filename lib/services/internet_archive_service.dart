import 'package:dio/dio.dart';
import '../models/site_movie.dart';

class InternetArchiveService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static Future<List<SiteMovie>> getMovies({int limit = 20}) async {
    try {
      final res = await _dio.get('https://archive.org/advancedsearch.php',
          queryParameters: {
            'q': 'collection:(feature_films) AND mediatype:(movies)',
            'fl[]': 'identifier,title,year,description,downloads',
            'sort[]': 'downloads desc',
            'rows': limit,
            'output': 'json',
          });
      final docs = (res.data['response']?['docs'] as List?) ?? [];
      final movies = <SiteMovie>[];
      for (final d in docs) {
        final m = await _withVideo(d);
        if (m != null) movies.add(m);
      }
      return movies;
    } catch (e) {
      return [];
    }
  }

  static Future<SiteMovie?> _withVideo(Map d) async {
    try {
      final id = (d['identifier'] ?? '').toString();
      if (id.isEmpty) return null;
      final meta = await _dio.get('https://archive.org/metadata/$id');
      final files = (meta.data['files'] as List?) ?? [];
      String? videoFile;
      for (final f in files) {
        final name = (f['name'] ?? '').toString();
        if (name.endsWith('.mp4') || name.endsWith('.avi') || name.endsWith('.mkv')) {
          videoFile = name;
          break;
        }
      }
      if (videoFile == null) return null;
      final url = 'https://archive.org/download/$id/$videoFile';
      return SiteMovie(
        id: 'ia_$id',
        title: (d['title'] ?? 'فيلم').toString(),
        year: (d['year'] ?? '').toString(),
        site: 'archive',
        videoUrl: url,
        poster: 'https://archive.org/services/img/$id',
        overview: _cleanDesc(d['description']),
        rating: 7.0,
        genres: ['كلاسيكي'],
        qualities: [VideoQuality(label: 'HD', url: url)],
      );
    } catch (_) {
      return null;
    }
  }

  static String _cleanDesc(dynamic d) {
    if (d is List) return d.join(' ');
    if (d is String) return d.length > 300 ? d.substring(0, 300) : d;
    return '';
  }
}
