class SiteMovie {
  final String id, title, year, site, videoUrl, poster, backdrop, overview, duration;
  final double rating;
  final List<String> genres;
  final List<VideoQuality> qualities;
  final bool hasSubtitle;
  final String? subtitleLang;
  final int? tmdbId;

  SiteMovie({
    required this.id, required this.title, required this.year,
    required this.site, required this.videoUrl,
    this.poster = '', this.backdrop = '', this.overview = '',
    this.rating = 0, this.duration = '', this.genres = const [],
    this.qualities = const [], this.hasSubtitle = false,
    this.subtitleLang, this.tmdbId,
  });

  bool get isMultiQuality => qualities.length > 1;
  String get qualityLabel => qualities.isEmpty
      ? '' : (isMultiQuality ? 'متعدد الجودات' : qualities.first.label);
  String get subtitleLabel => hasSubtitle ? 'مترجم' : 'بدون ترجمة';
  String get siteName {
    switch (site) {
      case 'plex': return 'Plex';
      case 'roku': return 'Roku';
      case 'crackle': return 'Crackle';
      case 'archive': return 'الأرشيف';
      default: return site;
    }
  }
}

class VideoQuality {
  final String label, url;
  final int bandwidth;
  VideoQuality({required this.label, required this.url, this.bandwidth = 0});
}
