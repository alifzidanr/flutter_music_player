// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_player_service.dart';
import 'now_playing_screen.dart';
import 'package:just_audio/just_audio.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  List<SongModel> _songs = [];
  bool _isLoading = true;
  bool _showNowPlayingCard = false;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _audioPlayerService.init();
    
    // Listen to player state changes to ensure UI updates
    _audioPlayerService.playerStateStream.listen((_) {
      // This ensures the UI updates when song changes
      if (mounted) {
        setState(() {});
      }
    });
    
    // Also listen to current song changes
    _audioPlayerService.currentSongStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }

  // Load songs from device
  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);

    try {
      // Query all songs
      final allSongs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // Filter to only MP3 files
      final mp3Songs =
          allSongs
              .where(
                (song) =>
                    song.fileExtension == "mp3" ||
                    (song.uri?.toLowerCase().endsWith('.mp3') ?? false),
              )
              .toList();

      setState(() {
        _songs = mp3Songs;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading songs: $e");
      setState(() => _isLoading = false);
    }
  }

  // Play selected song and show mini player
  void _playSong(SongModel song) async {
    print("Selected song: ${song.title} (ID: ${song.id})");
    
    try {
      // Show the now playing card immediately
      setState(() {
        _showNowPlayingCard = true;
      });
      
      // First, make sure the playlist is loaded with all songs
      await _audioPlayerService.loadPlaylist(
        _songs,
        initialIndex: 0,
        autoPlay: false
      );
      
      // Now play the selected song directly
      // Find the index of the song in the full songs list
      final songIndex = _songs.indexWhere((s) => s.id == song.id);
      if (songIndex != -1) {
        print("Found song at index: $songIndex");
        
        // If the song is already playing, just toggle play/pause
        if (_audioPlayerService.currentSong?.id == song.id) {
          await _audioPlayerService.togglePlayPause();
        } else {
          // Update song index in the service
          await _audioPlayerService.playSong(song);
        }
      } else {
        print("ERROR: Song not found in playlist");
      }
      
      // Force UI update
      setState(() {});
      
    } catch (e) {
      print("ERROR playing song: $e");
    }
  }

  // Open now playing screen
  void _openNowPlayingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NowPlayingScreen(audioPlayerService: _audioPlayerService),
      ),
    );
  }

  // Format duration as mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    Widget? bottomWidget;
    double listBottomPadding = 0;
    
    // Get the current song from the audio service
    final currentSong = _audioPlayerService.currentSong;
    
    // Determine the bottom widget and list padding based on state
    if (_showNowPlayingCard && currentSong != null) {
      bottomWidget = _buildNowPlayingCard();
      listBottomPadding = 280; // Approximate height of now playing card
    } else if (currentSong != null) {
      bottomWidget = _buildMiniPlayer();
      listBottomPadding = 65; // Mini player height + extra padding for navigation bar
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('MP3 Music Player'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSongs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? const Center(
                  child: Text(
                    "No MP3 files found on your device",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  // Add padding to ensure content isn't covered by player
                  padding: EdgeInsets.only(bottom: listBottomPadding),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    final isCurrentSong = currentSong?.id == song.id;

                    return ListTile(
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isCurrentSong ? FontWeight.bold : FontWeight.normal,
                          color:
                              isCurrentSong
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                      ),
                      subtitle: Text(
                        "${song.artist ?? 'Unknown Artist'} • ${_formatDuration(Duration(milliseconds: song.duration ?? 0))}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        nullArtworkWidget: const CircleAvatar(
                          child: Icon(Icons.music_note),
                        ),
                      ),
                      onTap: () => _playSong(song),
                    );
                  },
                ),
      // Set the bottom bar to our custom content, wrapped in SafeArea with extra bottom padding
      bottomNavigationBar: bottomWidget != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5.0), // Add extra padding for navigation bar
                child: bottomWidget,
              ),
              bottom: true,
            )
          : null,
    );
  }
  
  // Build the mini player for bottom navigation bar
  Widget _buildMiniPlayer() {
    return GestureDetector(
      onTap: _openNowPlayingScreen,
      onVerticalDragUpdate: (details) {
        // Detect upward swipe to expand mini player
        if (details.primaryDelta != null && details.primaryDelta! < -10) {
          setState(() {
            _showNowPlayingCard = true;
          });
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: StreamBuilder<PlayerState>(
          stream: _audioPlayerService.playerStateStream,
          builder: (context, snapshot) {
            final song = _audioPlayerService.currentSong;
            final isPlaying = snapshot.data?.playing ?? false;

            if (song == null) return const SizedBox.shrink();

            return ListTile(
              leading: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                nullArtworkWidget: const CircleAvatar(
                  child: Icon(Icons.music_note),
                ),
                size: 40,
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist ?? 'Unknown Artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: _audioPlayerService.togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _audioPlayerService.stop();
                      setState(() {
                        _showNowPlayingCard = false;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  // Build expanded now playing card
  Widget _buildNowPlayingCard() {
    final song = _audioPlayerService.currentSong;
    if (song == null) return const SizedBox.shrink();
    
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Now Playing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      onPressed: _openNowPlayingScreen,
                      tooltip: 'Fullscreen',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _showNowPlayingCard = false;
                        });
                      },
                      tooltip: 'Minimize',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: Row(
              children: [
                // Album art
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: QueryArtworkWidget(
                      id: song.id,
                      type: ArtworkType.AUDIO,
                      artworkBorder: BorderRadius.circular(8.0),
                      nullArtworkWidget: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Icon(
                          Icons.music_note,
                          size: 60,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Song info and controls
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist ?? 'Unknown Artist',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const Spacer(),
                        
                        // Progress bar
                        StreamBuilder<Duration>(
                          stream: _audioPlayerService.positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final duration = _audioPlayerService.duration;
                            
                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4.0,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6.0,
                                    ),
                                  ),
                                  child: Slider(
                                    value: position.inSeconds.toDouble(),
                                    min: 0.0,
                                    max: duration.inSeconds.toDouble() > 0 
                                        ? duration.inSeconds.toDouble() 
                                        : 1.0,
                                    onChanged: (value) {
                                      _audioPlayerService.seek(
                                        Duration(seconds: value.toInt()),
                                      );
                                    },
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(position)),
                                    Text(_formatDuration(duration)),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        
                        const Spacer(),
                        
                        // Playback controls with direct handling
                        StreamBuilder<PlayerState>(
                          stream: _audioPlayerService.playerStateStream,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data?.playing ?? false;
                            
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Previous button
                                GestureDetector(
                                  onTap: () async {
                                    print("Previous button pressed in now playing card");
                                    try {
                                      await _audioPlayerService.previous();
                                      setState(() {}); // Force UI update
                                    } catch (e) {
                                      print("Error on previous: $e");
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    child: const Icon(Icons.skip_previous),
                                  ),
                                ),
                                
                                // Play/Pause button
                                GestureDetector(
                                  onTap: () {
                                    print("Play/Pause button pressed in now playing card");
                                    _audioPlayerService.togglePlayPause();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    child: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                                
                                // Next button
                                GestureDetector(
                                  onTap: () async {
                                    print("Next button pressed in now playing card");
                                    try {
                                      await _audioPlayerService.next();
                                      setState(() {}); // Force UI update
                                    } catch (e) {
                                      print("Error on next: $e");
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    child: const Icon(Icons.skip_next),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}