import 'package:flutter/material.dart';
import '../models/site_movie.dart';
import '../services/sites_manager.dart';
import '../widgets/site_movie_card.dart';
import '../core.dart';
import '../lang.dart';  // ← أضف هذا السطر

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
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    setState(() => _loading = true);

    try {
      final movies = await SitesManager.getAllMovies(enrich: true);
      if (mounted) {
        setState(() {
          _movies = movies;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الأفلام: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSiteMovies(String site) async {
    setState(() {
      _selectedSite = site;
      _loading = true;
    });

    try {
      final movies = await SitesManager.getMoviesFromSite(site, enrich: true);
      if (mounted) {
        setState(() {
          _movies = movies;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الأفلام: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F14),
        title: const Text(
          'المواقع',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _selectedSite == 'all' 
                ? _loadMovies 
                : () => _loadSiteMovies(_selectedSite),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSiteButtons(),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _movies.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _selectedSite == 'all' 
                            ? _loadMovies 
                            : () => _loadSiteMovies(_selectedSite),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.55,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _movies.length,
                          itemBuilder: (context, index) {
                            return SiteMovieCard(movie: _movies[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildSiteButton('all', 'الكل', Icons.apps),
          const SizedBox(width: 8),
          if (SitesManager.isSiteEnabled('plex'))
            _buildSiteButton('plex', 'Plex', Icons.movie),
          if (SitesManager.isSiteEnabled('plex'))
            const SizedBox(width: 8),
          if (SitesManager.isSiteEnabled('roku'))
            _buildSiteButton('roku', 'Roku', Icons.tv),
          if (SitesManager.isSiteEnabled('roku'))
            const SizedBox(width: 8),
          if (SitesManager.isSiteEnabled('crackle'))
            _buildSiteButton('crackle', 'Crackle', Icons.play_circle),
        ],
      ),
    );
  }

  Widget _buildSiteButton(String site, String label, IconData icon) {
    final isSelected = _selectedSite == site;
    
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.accent 
                : const Color(0xFF1B2430),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.accent 
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black : Colors.white70,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_filter,
            size: 80,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد أفلام متاحة',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جرب تحديث القائمة أو التحقق من اتصالك',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
