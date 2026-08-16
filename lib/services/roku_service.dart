// lib/services/roku_service.dart

import 'package:dio/dio.dart';
import '../models/site_movie.dart';

class RokuService {
  static const String _baseUrl = 'https://therokuchannel.roku.com/api/v3';
  static const String _imageBase = 'https://image.roku.com/developer_channels/prod';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'Roku/DVP-9.10',
      'Accept': 'application/json',
    },
  ));

  static Future<List<SiteMovie>> getMovies({int limit = 100}) async {
    try {
      final response = await _dio.get('$_baseUrl/browse',
        queryParameters: {
          'categoryId': 'free-movies',
          'limit': limit,
        },
      );

      final items = response.data['content'] as List? ?? [];
      return items
          .where((item) => item['type'] == 'movie')
          .map((item) => _parseMovie(item))
          .toList();
    } catch (e) {
      print('Roku fetch error: $e');
      return [];
    }
  }

  static Future<List<SiteMovie>> search(String query) async {
    try {
      final response = await _dio.get('$_baseUrl/search',
        queryParameters: {
          'query': query,
          'limit': 20,
        },
      );

      final items = response.data['results'] as List? ?? [];
      return items
          .where((item) => item['type'] == 'movie')
          .map((item) => _parseMovie(item))
          .toList();
    } catch (e) {
      print('Roku search error: $e');
      return [];
    }
  }

  static SiteMovie _parseMovie(Map<String, dynamic> item) {
    final videoUrl = item['playbackUrl'] ?? item['url'] ?? '';
    
    final qualities = <VideoQuality>[
      VideoQuality(label: 'HD', url: videoUrl),
    ];

    return SiteMovie(
      id: 'roku_${item['id']}',
      title: item['title'] ?? '',
      year: item['releaseYear']?.toString() ?? '',
      site: 'roku',
      videoUrl: videoUrl,
      poster: item['thumbnail'] != null 
          ? '$_imageBase/${item['thumbnail']}' 
          : '',
      overview: item['description'] ?? '',
      rating: (item['rating'] ?? 0).toDouble(),
      duration: _formatDuration(item['duration'] ?? 0),
      qualities: qualities,
      genres: List<String>.from(item['genres'] ?? []),
    );
  }

  static String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }
}
