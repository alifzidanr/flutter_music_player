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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Now Playing'),
        elevation: 0,
      ),
      body: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final song = _player.currentSong;
          final isPlaying = snapshot.data?.playing ?? false;

          if (song == null) {
            return const Center(child: Text('No song selected'));
          }

          return Column(
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
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Icon(
                            Icons.music_note,
                            size: 120,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
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
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
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
                                  value: position.inSeconds.toDouble(),
                                  min: 0.0,
                                  max: duration.inSeconds.toDouble(),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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

                    // Playback controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          iconSize: 40,
                          onPressed: _player.previous,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            iconSize: 40,
                            padding: const EdgeInsets.all(12),
                            onPressed: _player.togglePlayPause,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          iconSize: 40,
                          onPressed: _player.next,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
