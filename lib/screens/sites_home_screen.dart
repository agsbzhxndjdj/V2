import 'package:flutter/material.dart';
import '../models/site_movie.dart';
import '../services/sites_manager.dart';
import '../widgets/site_movie_card.dart';
import '../core.dart';
import '../lang.dart';

class SitesHomeScreen extends StatefulWidget {
  const SitesHomeScreen({super.key});
  @override
  State<SitesHomeScreen> createState() => _SitesHomeScreenState();
}

class _SitesHomeScreenState extends State<SitesHomeScreen> {
  List<SiteMovie> _movies = [];
  bool _loading = true;
  String _selectedSite = 'all';

  @override
  void initState() { super.initState(); _loadMovies(); }

  Future<void> _loadMovies() async {
    setState(() => _loading = true);
    try {
      final movies = await SitesManager.getAllMovies();
      if (mounted) setState(() { _movies = movies; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSiteMovies(String site) async {
    setState(() { _selectedSite = site; _loading = true; });
    try {
      final movies = await SitesManager.getMoviesFromSite(site);
      if (mounted) setState(() { _movies = movies; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F14),
        title: const Text('المواقع', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _selectedSite == 'all' ? _loadMovies : () => _loadSiteMovies(_selectedSite),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _btn('all', 'الكل', Icons.apps),
            const SizedBox(width: 6),
            _btn('archive', 'الأرشيف', Icons.folder_open),
            const SizedBox(width: 6),
            _btn('plex', 'Plex', Icons.movie),
            const SizedBox(width: 6),
            _btn('roku', 'Roku', Icons.tv),
            const SizedBox(width: 6),
            _btn('crackle', 'Crackle', Icons.play_circle),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _movies.isEmpty
                  ? const Center(child: Text('لا توجد أفلام', style: TextStyle(color: Colors.grey)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _movies.length,
                      itemBuilder: (c, i) => SiteMovieCard(movie: _movies[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _btn(String site, String label, IconData icon) {
    final sel = _selectedSite == site;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (site == 'all') {
            setState(() => _selectedSite = 'all');
            _loadMovies();
          } else {
            _loadSiteMovies(site);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppTheme.accent : const Color(0xFF1B2430),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? AppTheme.accent : Colors.transparent, width: 2,
            ),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? Colors.black : Colors.white70, size: 18),
            const SizedBox(height: 3),
            FittedBox(
              child: Text(label, style: TextStyle(
                color: sel ? Colors.black : Colors.white,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              )),
            ),
          ]),
        ),
      ),
    );
  }
}
