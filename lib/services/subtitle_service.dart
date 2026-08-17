// lib/services/subtitle_service.dart

import 'package:dio/dio.dart';

class SubtitleService {
  static const String _baseUrl = 'https://api.opensubtitles.com/api/v1';
  static const String _apiKey = '56G4MJyCa7BeMwW8P7mNIJeZAlsUH6yp'; // ⚠️ ضع مفتاحك هنا
  
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Api-Key': _apiKey,
      'User-Agent': 'TeleCinema v2.0',
      'Content-Type': 'application/json',
    },
  ));

  static Future<SubtitleInfo?> findBestSubtitle({
    required String title,
    String? year,
    int? tmdbId,
    List<String> languages = const ['ar', 'en'],
  }) async {
    for (final lang in languages) {
      try {
        final response = await _dio.get('/subtitles', queryParameters: {
          'query': title,
          'languages': lang,
          if (tmdbId != null) 'tmdb_id': tmdbId,
          if (year != null && year.isNotEmpty) 'year': year,
          'order_by': 'download_count',
          'order_direction': 'desc',
        });

        final data = response.data['data'] as List;
        if (data.isNotEmpty) {
          final sorted = data.map((item) => _parseSubtitle(item)).toList()
            ..sort((a, b) {
              final scoreA = a.downloadCount + (a.rating * 1000).toInt();
              final scoreB = b.downloadCount + (b.rating * 1000).toInt();
              return scoreB.compareTo(scoreA);
            });

          if (sorted.isNotEmpty) {
            return sorted.first;
          }
        }
      } catch (e) {
        print('Subtitle search error for $lang: $e');
      }
    }
    return null;
  }

  static Future<String?> downloadSubtitleContent(int fileId) async {
    try {
      final response = await _dio.post('/download', data: {
        'file_id': fileId,
      });

      final downloadUrl = response.data['link'] as String?;
      if (downloadUrl == null) return null;

      final contentResponse = await Dio().get(downloadUrl);
      return contentResponse.data as String;
    } catch (e) {
      print('Subtitle download error: $e');
      return null;
    }
  }

  static Future<bool> hasSubtitle({
    required String title,
    int? tmdbId,
  }) async {
    try {
      final response = await _dio.get('/subtitles', queryParameters: {
        'query': title,
        'languages': 'ar',
        if (tmdbId != null) 'tmdb_id': tmdbId,
      });

      final data = response.data['data'] as List;
      return data.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static SubtitleInfo _parseSubtitle(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>;
    final files = attributes['files'] as List;

    return SubtitleInfo(
      fileId: files.isNotEmpty ? files[0]['file_id'] as int : 0,
      fileName: files.isNotEmpty ? files[0]['file_name'] as String : '',
      language: attributes['language'] as String? ?? 'ar',
      rating: (attributes['ratings'] as num?)?.toDouble() ?? 0.0,
      downloadCount: attributes['download_count'] as int? ?? 0,
      author: attributes['uploader']?['name'] as String? ?? '',
    );
  }
}

class SubtitleInfo {
  final int fileId;
  final String fileName;
  final String language;
  final double rating;
  final int downloadCount;
  final String author;

  SubtitleInfo({
    required this.fileId,
    required this.fileName,
    required this.language,
    required this.rating,
    required this.downloadCount,
    required this.author,
  });
}
