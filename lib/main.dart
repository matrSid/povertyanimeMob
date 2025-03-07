import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: AnimeApp()));
}

// Theme definition
class AppTheme {
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color accentColor = Color(0xFFFF9FF3);
  static const Color backgroundColor = Color(0xFF191921);
  static const Color cardColor = Color(0xFF252533);
  static const Color textColor = Color(0xFFF5F5F7);
  static const Color secondaryTextColor = Color(0xFFADADB8);
  static const Color searchBarColor = Color(0xFF2C2C3B);

  static ThemeData darkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      cardColor: cardColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: cardColor,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
    );
  }
}

class AnimeApp extends StatelessWidget {
  const AnimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LunaAnime',
      theme: AppTheme.darkTheme(),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

// Models
class Anime {
  final String id;
  final String name;
  final String img;

  Anime({
    required this.id,
    required this.name,
    required this.img,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'],
      name: json['name'],
      img: json['img'],
    );
  }
}

class Episode {
  final String episodeId;
  final String episodeNo;
  final String? name;

  Episode({
    required this.episodeId,
    required this.episodeNo,
    this.name,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      episodeId: json['episodeId'],
      episodeNo: json['episodeNo'].toString(),
      name: json['name'],
    );
  }
}

class Subtitle {
  final String file;
  final String label;
  final String kind;

  Subtitle({
    required this.file,
    required this.label,
    required this.kind,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      file: json['file'],
      label: json['label'],
      kind: json['kind'],
    );
  }
}

// API Service
class AnimeApiService {
  static const String apiBaseUrl = 'https://animeapiworks.vercel.app/aniwatch';

  static Future<List<Anime>> fetchPopularAnime() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final animeList = (data['featuredAnimes']['mostPopularAnimes'] as List)
            .map((anime) => Anime.fromJson(anime))
            .toList();
        return animeList;
      } else {
        throw Exception('Failed to load popular anime');
      }
    } catch (e) {
      print('Error fetching popular anime: $e');
      return [];
    }
  }

  static Future<List<Anime>> searchAnime(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/search?keyword=${Uri.encodeComponent(query)}&page=1'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final animeList = (data['animes'] as List)
            .map((anime) => Anime.fromJson(anime))
            .toList();
        return animeList;
      } else {
        throw Exception('Failed to search anime');
      }
    } catch (e) {
      print('Error searching anime: $e');
      return [];
    }
  }

  static Future<Anime?> getAnimeDetails(String animeId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/anime/${Uri.encodeComponent(animeId)}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Anime(
          id: data['info']['id'],
          name: data['info']['name'],
          img: data['info']['img'],
        );
      } else {
        throw Exception('Failed to get anime details');
      }
    } catch (e) {
      print('Error getting anime details: $e');
      return null;
    }
  }

  static Future<List<Episode>> getEpisodes(String animeId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/episodes/${Uri.encodeComponent(animeId)}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final episodeList = (data['episodes'] as List)
            .map((episode) => Episode.fromJson(episode))
            .toList();
        return episodeList;
      } else {
        throw Exception('Failed to get episodes');
      }
    } catch (e) {
      print('Error getting episodes: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getEpisodeSource(String episodeId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/episode-srcs?id=${Uri.encodeComponent(episodeId)}&server=vidstreaming&category=sub'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['sources'] != null && data['sources'].length > 0) {
          final url = data['sources'][0]['url'];
          
          List<Subtitle> subtitles = [];
          if (data['tracks'] != null) {
            subtitles = (data['tracks'] as List)
                .where((track) => track['kind'] == 'captions')
                .map((track) => Subtitle.fromJson(track))
                .toList();
            
            // Sort to prioritize English subtitles
            subtitles.sort((a, b) {
              final aIsEnglish = a.label.toLowerCase().contains('english') ? 0 : 1;
              final bIsEnglish = b.label.toLowerCase().contains('english') ? 0 : 1;
              return aIsEnglish - bIsEnglish;
            });
          }
          
          return {
            'url': url,
            'subtitles': subtitles,
          };
        }
      }
      return null;
    } catch (e) {
      print('Error getting episode source: $e');
      return null;
    }
  }
}

// Providers
final popularAnimeProvider = FutureProvider<List<Anime>>((ref) async {
  return AnimeApiService.fetchPopularAnime();
});

final searchResultsProvider = StateProvider<List<Anime>>((ref) => []);
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedAnimeProvider = StateProvider<Anime?>((ref) => null);
final episodesProvider = StateProvider<List<Episode>>((ref) => []);
final currentEpisodeProvider = StateProvider<Episode?>((ref) => null);
final videoUrlProvider = StateProvider<String?>((ref) => null);
final subtitlesProvider = StateProvider<List<Subtitle>>((ref) => []);

// Home Page
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _searchAnime() async {
    final query = _searchController.text;
    ref.read(searchQueryProvider.notifier).state = query;
    
    if (query.trim().isNotEmpty) {
      final results = await AnimeApiService.searchAnime(query);
      ref.read(searchResultsProvider.notifier).state = results;
    }
  }

  void _selectAnime(Anime anime) async {
    ref.read(selectedAnimeProvider.notifier).state = anime;
    final episodes = await AnimeApiService.getEpisodes(anime.id);
    ref.read(episodesProvider.notifier).state = episodes;
    _showAnimeDetailsModal();
  }

  void _showAnimeDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AnimeDetailsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final popularAnime = ref.watch(popularAnimeProvider);
    final searchResults = ref.watch(searchResultsProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              title: const Text(
                'LunaAnime',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.brightness_4),
                  onPressed: () {
                    // Theme toggle would go here
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.searchBarColor,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search anime...',
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.search),
                              contentPadding: EdgeInsets.symmetric(vertical: 15),
                            ),
                            onSubmitted: (_) => _searchAnime(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _searchAnime,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Icon(Icons.search),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  searchQuery.isNotEmpty && searchResults.isNotEmpty
                      ? 'Results for "$searchQuery"'
                      : 'Popular Anime',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            searchQuery.isNotEmpty && searchResults.isNotEmpty
                ? _buildAnimeGrid(searchResults)
                : popularAnime.when(
                    data: (animeList) => _buildAnimeGrid(animeList),
                    loading: () => const SliverToBoxAdapter(
                      child: Center(
                        child: SpinKitPulse(
                          color: AppTheme.primaryColor,
                          size: 50.0,
                        ),
                      ),
                    ),
                    error: (error, stackTrace) => SliverToBoxAdapter(
                      child: Center(
                        child: Text('Error: $error'),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeGrid(List<Anime> animeList) {
    return SliverPadding(
      padding: const EdgeInsets.all(8.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final anime = animeList[index];
            return AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: AnimePosterCard(
                    anime: anime,
                    onTap: () => _selectAnime(anime),
                    index: index,
                  ),
                );
              },
            );
          },
          childCount: animeList.length,
        ),
      ),
    );
  }
}

class AnimePosterCard extends StatefulWidget {
  final Anime anime;
  final VoidCallback onTap;
  final int index;

  const AnimePosterCard({
    super.key,
    required this.anime,
    required this.onTap,
    required this.index,
  });

  @override
  State<AnimePosterCard> createState() => _AnimePosterCardState();
}

class _AnimePosterCardState extends State<AnimePosterCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: Hero(
          tag: 'anime-${widget.anime.id}',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.anime.img,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.cardColor,
                      child: const Center(
                        child: SpinKitPulse(
                          color: AppTheme.primaryColor,
                          size: 30.0,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.cardColor,
                      child: const Icon(Icons.error),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        widget.anime.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              blurRadius: 3.0,
                              color: Colors.black,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.yellow, size: 16),
                          SizedBox(width: 4),
                          Text('New', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Anime Details & Episode List Modal
class AnimeDetailsSheet extends ConsumerStatefulWidget {
  const AnimeDetailsSheet({super.key});

  @override
  ConsumerState<AnimeDetailsSheet> createState() => _AnimeDetailsSheetState();
}

class _AnimeDetailsSheetState extends ConsumerState<AnimeDetailsSheet> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _playEpisode(Episode episode) async {
    final source = await AnimeApiService.getEpisodeSource(episode.episodeId);
    if (source != null) {
      final url = source['url'];
      final subtitles = source['subtitles'] as List<Subtitle>;
      
      ref.read(currentEpisodeProvider.notifier).state = episode;
      ref.read(videoUrlProvider.notifier).state = url;
      ref.read(subtitlesProvider.notifier).state = subtitles;
      
      // Initialize video player
      _initializeVideoPlayer(url, subtitles);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load video source')),
      );
    }
  }

  void _initializeVideoPlayer(String url, List<Subtitle> subtitles) async {
    // Dispose previous controllers if they exist
    _videoController?.dispose();
    _chewieController?.dispose();
    
    setState(() {
      _isVideoInitialized = false;
    });
    
    _videoController = VideoPlayerController.network(url);
    
    try {
      await _videoController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: SpinKitCircle(
              color: AppTheme.primaryColor,
              size: 50.0,
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      
      setState(() {
        _isVideoInitialized = true;
      });
    } catch (e) {
      print('Error initializing video player: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading video: $e')),
      );
    }
  }

  void _closeDetails() {
    _animationController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedAnime = ref.watch(selectedAnimeProvider);
    final episodes = ref.watch(episodesProvider);
    final currentEpisode = ref.watch(currentEpisodeProvider);
    final videoUrl = ref.watch(videoUrlProvider);
    final size = MediaQuery.of(context).size;
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, size.height * _slideAnimation.value),
          child: child,
        );
      },
      child: Container(
        height: size.height * 0.9,
        decoration: const BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 60,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Video player section
                      Container(
                        height: 230,
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: videoUrl != null && _isVideoInitialized
                              ? Chewie(controller: _chewieController!)
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      videoUrl != null
                                          ? const SpinKitRipple(
                                              color: AppTheme.primaryColor,
                                              size: 50.0,
                                            )
                                          : SvgPicture.asset(
                                              'assets/images/play_illustration.svg',
                                              height: 100,
                                              semanticsLabel: 'Play Illustration',
                                            ),
                                      const SizedBox(height: 16),
                                      Text(
                                        videoUrl != null
                                            ? 'Loading video...'
                                            : 'Select an episode to play',
                                        style: TextStyle(
                                          color: AppTheme.secondaryTextColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),

                      // Title and episodes header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                selectedAnime?.name ?? 'Loading...',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            currentEpisode != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'EP ${currentEpisode.episodeNo}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : const SizedBox(),
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'Episodes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Episodes list
                      Expanded(
                        child: episodes.isEmpty
                            ? const Center(
                                child: SpinKitThreeBounce(
                                  color: AppTheme.primaryColor,
                                  size: 30.0,
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: episodes.length,
                                itemBuilder: (context, index) {
                                  final episode = episodes[index];
                                  return EpisodeListTile(
                                    episode: episode,
                                    isSelected: currentEpisode?.episodeId == episode.episodeId,
                                    onTap: () => _playEpisode(episode),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // Close button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: _closeDetails,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EpisodeListTile extends StatelessWidget {
  final Episode episode;
  final bool isSelected;
  final VoidCallback onTap;

  const EpisodeListTile({
    super.key,
    required this.episode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : AppTheme.primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                episode.episodeNo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          title: Text(
            episode.name ?? 'Episode ${episode.episodeNo}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppTheme.textColor,
            ),
          ),
          trailing: Icon(
            Icons.play_circle_outline,
            color: isSelected ? Colors.white : AppTheme.primaryColor,
          ),
        ),
      ),
      );
  }
}