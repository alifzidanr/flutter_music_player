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

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _audioPlayerService.init();
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

  // Play selected song and open now playing screen
  void _playSong(SongModel song) async {
    await _audioPlayerService.loadPlaylist(
      _songs,
      initialIndex: _songs.indexWhere((s) => s.id == song.id),
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                NowPlayingScreen(audioPlayerService: _audioPlayerService),
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
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _songs.isEmpty
              ? const Center(
                child: Text(
                  "No MP3 files found on your device",
                  style: TextStyle(fontSize: 16),
                ),
              )
              : ListView.builder(
                itemCount: _songs.length,
                itemBuilder: (context, index) {
                  final song = _songs[index];
                  final isCurrentSong =
                      _audioPlayerService.currentSong?.id == song.id;

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
      // Mini player at bottom when a song is selected
      bottomNavigationBar:
          _audioPlayerService.currentSong != null
              ? GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => NowPlayingScreen(
                            audioPlayerService: _audioPlayerService,
                          ),
                    ),
                  );
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
                        trailing: IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: _audioPlayerService.togglePlayPause,
                        ),
                      );
                    },
                  ),
                ),
              )
              : null,
    );
  }
}
