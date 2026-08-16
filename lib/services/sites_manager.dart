// lib/services/sites_manager.dart

import '../models/site_movie.dart';
import 'plex_service.dart';
import 'roku_service.dart';
import 'crackle_service.dart';
import 'tmdb_service.dart';
import 'subtitle_service.dart';
import '../core.dart';

class SitesManager {
  static const List<String> availableSites = ['plex', 'roku', 'crackle'];

  static bool get isSitesEnabled => Store.getBool('sites_enabled', true);

  static Future<void> setSitesEnabled(bool enabled) async {
    await Store.setPref('sites_enabled', enabled);
  }

  static bool isSiteEnabled(String site) {
    return Store.getBool('site_$site', true);
  }

  static Future<void> setSiteEnabled(String site, bool enabled) async {
    await Store.setPref('site_$site', enabled);
  }

  static Future<List<SiteMovie>> getAllMovies({bool enrich = true}) async {
    final futures = <Future<List<SiteMovie>>>[];

    if (isSiteEnabled('plex')) futures.add(PlexService.getMovies());
    if (isSiteEnabled('roku')) futures.add(RokuService.getMovies());
    if (isSiteEnabled('crackle')) futures.add(CrackleService.getMovies());

    final results = await Future.wait(futures);
    var movies = results.expand((list) => list).toList();

    movies = _removeDuplicates(movies);
    movies = _mergeSeries(movies);

    if (enrich) {
      movies = await _enrichMovies(movies);
    }

    return movies;
  }

  static Future<List<SiteMovie>> getMoviesFromSite(String site, {bool enrich = true}) async {
    List<SiteMovie> movies;

    switch (site) {
      case 'plex':
        movies = await PlexService.getMovies();
        break;
      case 'roku':
        movies = await RokuService.getMovies();
        break;
      case 'crackle':
        movies = await CrackleService.getMovies();
        break;
      default:
        movies = [];
    }

    movies = _removeDuplicates(movies);

    if (enrich) {
      movies = await _enrichMovies(movies);
    }

    return movies;
  }

  static Future<List<SiteMovie>> search(String query) async {
    final futures = <Future<List<SiteMovie>>>[];

    if (isSiteEnabled('plex')) futures.add(PlexService.search(query));
    if (isSiteEnabled('roku')) futures.add(RokuService.search(query));
    if (isSiteEnabled('crackle')) futures.add(CrackleService.search(query));

    final results = await Future.wait(futures);
    var movies = results.expand((list) => list).toList();

    movies = _removeDuplicates(movies);
    movies = await _enrichMovies(movies);

    return movies;
  }

  static Future<List<SiteMovie>> _enrichMovies(List<SiteMovie> movies) async {
    final enriched = <SiteMovie>[];

    for (var i = 0; i < movies.length; i += 5) {
      final batch = movies.skip(i).take(5);
      final futures = batch.map((movie) async {
        var enrichedMovie = await TmdbService.enrichMovie(movie);

        try {
          final hasSub = await SubtitleService.hasSubtitle(
            title: enrichedMovie.title,
            tmdbId: enrichedMovie.tmdbId,
          );
          enrichedMovie = enrichedMovie.copyWith(
            hasSubtitle: hasSub,
            subtitleLang: hasSub ? 'ar' : null,
          );
        } catch (_) {}

        return enrichedMovie;
      });

      enriched.addAll(await Future.wait(futures));
      
      if (i + 5 < movies.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    return enriched;
  }

  static List<SiteMovie> _removeDuplicates(List<SiteMovie> movies) {
    final seen = <String>{};
    final unique = <SiteMovie>[];

    for (final movie in movies) {
      final key = _normalizeTitle(movie.title);
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(movie);
      }
    }

    return unique;
  }

  static List<SiteMovie> _mergeSeries(List<SiteMovie> movies) {
    final seriesMap = <String, List<SiteMovie>>{};
    final standalone = <SiteMovie>[];

    final partPattern = RegExp(r'(Part|جزء|الجزء)\s*(\d+)', caseSensitive: false);

    for (final movie in movies) {
      final match = partPattern.firstMatch(movie.title);
      if (match != null) {
        final seriesTitle = movie.title
            .replaceAll(partPattern, '')
            .trim();
        final key = _normalizeTitle(seriesTitle);
        
        seriesMap.putIfAbsent(key, () => []).add(movie);
      } else {
        standalone.add(movie);
      }
    }

    final merged = <SiteMovie>[...standalone];
    
    for (final parts in seriesMap.values) {
      if (parts.length == 1) {
        merged.add(parts.first);
      } else {
        parts.sort((a, b) => a.title.compareTo(b.title));
        final base = parts.first;
        
        final allQualities = <VideoQuality>[
          ...base.qualities,
          ...parts.skip(1).expand((p) => p.qualities),
        ];

        merged.add(SiteMovie(
          id: base.id,
          title: base.title.replaceAll(partPattern, '').trim(),
          year: base.year,
          site: base.site,
          videoUrl: base.videoUrl,
          poster: base.poster,
          backdrop: base.backdrop,
          overview: base.overview,
          rating: base.rating,
          duration: base.duration,
          genres: base.genres,
          qualities: allQualities,
          hasSubtitle: base.hasSubtitle,
          subtitleLang: base.subtitleLang,
          tmdbId: base.tmdbId,
        ));
      }
    }

    return merged;
  }

  static String _normalizeTitle(String title) {
    var t = title.toLowerCase().trim();
    t = t.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '');
    t = t.replaceAll(RegExp(
      r'\b(2160p|1080p|720p|480p|4k|uhd|bluray|web-?dl|hdrip)\b',
      caseSensitive: false,
    ), '');
    t = t.replaceAll(RegExp(r'(Part|جزء)\s*\d+', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'[^\w\s]', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }
}
