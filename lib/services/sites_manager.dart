import '../models/site_movie.dart';
import 'internet_archive_service.dart';
import 'plex_service.dart';
import 'roku_service.dart';
import 'crackle_service.dart';

class SitesManager {
  static bool isSiteEnabled(String site) => true;

  static Future<List<SiteMovie>> getAllMovies({bool enrich = true}) async {
    final all = <SiteMovie>[];
    all.addAll(await InternetArchiveService.getMovies());
    all.addAll(await PlexService.getMovies());
    all.addAll(await RokuService.getMovies());
    all.addAll(await CrackleService.getMovies());
    return _dedup(all);
  }

  static Future<List<SiteMovie>> getMoviesFromSite(String site, {bool enrich = true}) async {
    List<SiteMovie> list;
    switch (site) {
      case 'plex': list = await PlexService.getMovies(); break;
      case 'roku': list = await RokuService.getMovies(); break;
      case 'crackle': list = await CrackleService.getMovies(); break;
      case 'archive':
      default: list = await InternetArchiveService.getMovies();
    }
    return list;
  }

  static Future<List<SiteMovie>> search(String query) async => [];

  static List<SiteMovie> _dedup(List<SiteMovie> l) {
    final seen = <String>{};
    return l.where((m) => seen.add(m.title)).toList();
  }
}
