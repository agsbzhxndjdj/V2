// lib/services/crackle_service.dart

import 'package:dio/dio.dart';
import '../models/site_movie.dart';

class CrackleService {
  static const String _baseUrl = 'https://web-api-us.crackle.com/Service.svc';
  static const String _imageBase = 'https://images-us-am.crackle.com';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      'Accept': 'application/json',
    },
  ));

  static Future<List<SiteMovie>> getMovies({int limit = 100}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/browse/movies',
        queryParameters: {
          'count': limit,
          'country': 'us',
        },
      );

      final items = response.data['Items'] as List? ?? [];
      return items.map((item) => _parseMovie(item)).toList();
    } catch (e) {
      print('Crackle fetch error: $e');
      return [];
    }
  }

  static Future<List<SiteMovie>> search(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'query': query,
          'country': 'us',
        },
      );

      final items = response.data['Items'] as List? ?? [];
      return items
          .where((item) => item['Type'] == 'Movie')
          .map((item) => _parseMovie(item))
          .toList();
    } catch (e) {
      print('Crackle search error: $e');
      return [];
    }
  }

  static SiteMovie _parseMovie(Map<String, dynamic> item) {
    final videoUrl = item['MediaUrl'] ?? item['StreamUrl'] ?? '';
    
    return SiteMovie(
      id: 'crackle_${item['ID'] ?? item['Slug']}',
      title: item['Title'] ?? item['Name'] ?? '',
      year: item['ReleaseYear']?.toString() ?? '',
      site: 'crackle',
      videoUrl: videoUrl,
      poster: item['ImagePath'] != null 
          ? '$_imageBase/${item['ImagePath']}' 
          : '',
      overview: item['Description'] ?? '',
      rating: (item['Rating'] ?? 0).toDouble(),
      duration: item['Runtime'] ?? '',
      genres: List<String>.from(item['Genres'] ?? []),
      qualities: [
        VideoQuality(label: 'HD', url: videoUrl),
      ],
    );
  }
}
