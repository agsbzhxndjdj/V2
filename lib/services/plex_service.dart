// lib/services/plex_service.dart

import 'package:dio/dio.dart';
import '../models/site_movie.dart';

class PlexService {
  static const String _plexToken = 'claim-6rPWv-U4idkMhmJ3P5UX'; // ⚠️ ضع token من https://www.plex.tv/claim/
  static const String _baseUrl = 'https://vod.provider.plex.tv';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'X-Plex-Token': _plexToken,
      'Accept': 'application/json',
    },
  ));

  static Future<List<SiteMovie>> getMovies({int limit = 100}) async {
    try {
      final response = await _dio.get('$_baseUrl/library/sections/1/all',
        queryParameters: {
          'type': 1,
          'limit': limit,
        },
      );

      final metadata = response.data['MediaContainer']?['Metadata'] as List? ?? [];
      
      return metadata.map((item) => _parseMovie(item)).toList();
    } catch (e) {
      print('Plex fetch error: $e');
      return [];
    }
  }

  static Future<List<SiteMovie>> search(String query) async {
    try {
      final response = await _dio.get('$_baseUrl/hubs/search',
        queryParameters: {
          'query': query,
          'sectionId': 1,
          'limit': 20,
        },
      );

      final hubs = response.data['MediaContainer']?['Hub'] as List? ?? [];
      final results = <SiteMovie>[];

      for (final hub in hubs) {
        final items = hub['Metadata'] as List? ?? [];
        for (final item in items) {
          if (item['type'] == 'movie') {
            results.add(_parseMovie(item));
          }
        }
      }

      return results;
    } catch (e) {
      print('Plex search error: $e');
      return [];
    }
  }

  static SiteMovie _parseMovie(Map<String, dynamic> item) {
    final media = item['Media'] as List? ?? [];
    final qualities = <VideoQuality>[];

    for (final m in media) {
      final parts = m['Part'] as List? ?? [];
      for (final part in parts) {
        final quality = _getQualityLabel(m['videoResolution']?.toString() ?? '');
        qualities.add(VideoQuality(
          label: quality,
          url: '$_baseUrl${part['key']}',
          bandwidth: m['bitrate'] ?? 0,
        ));
      }
    }

    return SiteMovie(
      id: 'plex_${item['ratingKey']}',
      title: item['title'] ?? '',
      year: item['year']?.toString() ?? '',
      site: 'plex',
      videoUrl: qualities.isNotEmpty ? qualities.first.url : '',
      poster: item['thumb'] != null 
          ? '$_baseUrl${item['thumb']}?X-Plex-Token=$_plexToken' 
          : '',
      backdrop: item['art'] != null 
          ? '$_baseUrl${item['art']}?X-Plex-Token=$_plexToken' 
          : '',
      overview: item['summary'] ?? '',
      rating: (item['rating'] ?? 0).toDouble(),
      duration: _formatDuration(item['duration'] ?? 0),
      qualities: qualities,
      genres: (item['Genre'] as List? ?? [])
          .map((g) => g['tag'] as String)
          .toList(),
    );
  }

  static String _getQualityLabel(String resolution) {
    switch (resolution.toLowerCase()) {
      case '4k':
      case '2160':
        return '4K';
      case '1080':
        return '1080p';
      case '720':
        return '720p';
      case '480':
        return '480p';
      default:
        return resolution.isNotEmpty ? resolution : 'SD';
    }
  }

  static String _formatDuration(int milliseconds) {
    final minutes = milliseconds ~/ 60000;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }
}
