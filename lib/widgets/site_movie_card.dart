import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/site_movie.dart';
import '../core.dart';
import '../lang.dart';
import '../tv.dart';

class SiteMovieCard extends StatelessWidget {
  final SiteMovie movie;
  const SiteMovieCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final m = Movie(
      channel: movie.site,
      msgId: movie.id.hashCode.abs(),
      title: movie.title,
      poster: movie.poster,
      videoUrl: movie.videoUrl,
      description: movie.overview,
      genres: movie.genres,
      quality: movie.qualityLabel,
      size: '',
      duration: movie.duration,
      date: DateTime.now().millisecondsSinceEpoch,
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TvPlayer(movie: m)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1B2430),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(fit: StackFit.expand, children: [
            movie.poster.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: movie.poster,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF1B2430),
                      child: const Icon(Icons.movie, color: Colors.grey),
                    ),
                  )
                : Container(
                    color: const Color(0xFF1B2430),
                    child: const Icon(Icons.movie, color: Colors.grey),
                  ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (movie.qualityLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(movie.qualityLabel, style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black,
                          )),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(movie.siteName, style: const TextStyle(
                  fontSize: 9, color: Colors.white,
                )),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
