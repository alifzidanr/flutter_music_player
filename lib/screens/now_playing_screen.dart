// lib/screens/now_playing_screen.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_player_service.dart';

class NowPlayingScreen extends StatefulWidget {
  final AudioPlayerService audioPlayerService;

  const NowPlayingScreen({super.key, required this.audioPlayerService});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  AudioPlayerService get _player => widget.audioPlayerService;
  
  @override 
  void initState() {
    super.initState();
    
    // Listen to player state changes to update UI
    _player.playerStateStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    
    // Listen to current song changes
    _player.currentSongStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
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
    final song = _player.currentSong;
    final isPlaying = _player.isPlaying;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Now Playing'),
          elevation: 0,
        ),
        body: const Center(child: Text('No song selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Now Playing'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Album art area
          Expanded(
            flex: 5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkBorder: BorderRadius.circular(8.0),
                    artworkWidth: double.infinity,
                    artworkHeight: double.infinity,
                    nullArtworkWidget: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 120,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Song info
          Expanded(
            flex: 4,
            child: Column(
              children: [
                // Song title and artist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Text(
                        song.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.artist ?? 'Unknown Artist',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = _player.duration;
                      
                      // Safety check for invalid duration
                      final maxValue = duration.inSeconds > 0 
                          ? duration.inSeconds.toDouble() 
                          : 1.0;

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4.0,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6.0,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14.0,
                              ),
                            ),
                            child: Slider(
                              value: position.inSeconds.toDouble().clamp(0, maxValue),
                              min: 0.0,
                              max: maxValue,
                              onChanged: (value) {
                                _player.seek(
                                  Duration(seconds: value.toInt()),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position)),
                                Text(_formatDuration(duration)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Playback controls with direct handling
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous button with direct handling
                    GestureDetector(
                      onTap: () async {
                        print("Previous button pressed in NowPlayingScreen");
                        try {
                          setState(() {
                            // Show loading state if needed
                          });
                          await _player.previous();
                          setState(() {
                            // Update UI after operation completes
                          });
                        } catch (e) {
                          print("Error in previous button: $e");
                          // Show error if needed
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.skip_previous,
                          size: 40,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Play/Pause button
                    GestureDetector(
                      onTap: () {
                        print("Play/Pause button pressed in NowPlayingScreen");
                        _player.togglePlayPause();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 40,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Next button with direct handling
                    GestureDetector(
                      onTap: () async {
                        print("Next button pressed in NowPlayingScreen");
                        try {
                          setState(() {
                            // Show loading state if needed
                          });
                          await _player.next();
                          setState(() {
                            // Update UI after operation completes
                          });
                        } catch (e) {
                          print("Error in next button: $e");
                          // Show error if needed
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.skip_next,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),

                // Add extra padding at the bottom
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}