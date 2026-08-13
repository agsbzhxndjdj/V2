import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'ui_detail.dart';
import 'core.dart';

class MovieCard extends StatelessWidget {
  final Movie m;
  const MovieCard({super.key, required this.m});
  @override
  Widget build(BuildContext context) {
    final dl = Store.downloads().containsKey(m.id);
    final watched = Store.history().any((e) => e.id == m.id);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(m: m))),
      child: ClipRRect(borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          m.poster.isNotEmpty
              ? CachedNetworkImage(imageUrl: m.poster, fit: BoxFit.cover, memCacheWidth: 300,
                  placeholder: (_, __) => Container(color: const Color(0xFF151B23)),
                  errorWidget: (_, __, ___) => _ph())
              : _ph(),
          Container(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(.88)]))),
          Positioned(top: 4, left: 4, child: Row(children: [
            if (watched) const Icon(Icons.check_circle, size: 15, color: Colors.green),
            if (dl) const Icon(Icons.download_done, size: 15, color: Colors.amber),
          ])),
          if (m.quality.isNotEmpty)
            Positioned(top: 4, right: 4, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                child: Text(m.quality, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)))),
          Positioned(bottom: 6, left: 6, right: 6, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            if (m.size.isNotEmpty)
              Text(m.size, style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
          ])),
        ])),
    );
  }

  Widget _ph() => Container(color: const Color(0xFF151B23),
      child: const Icon(Icons.movie_outlined, size: 40, color: Colors.grey));
}
