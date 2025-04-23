// services/audio_player_service.dart

import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Event streams
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  // Current playback state
  bool get isPlaying => _audioPlayer.playing;
  Duration get duration => _audioPlayer.duration ?? Duration.zero;
  Duration get position => _audioPlayer.position;

  // Playlist management
  List<SongModel> _playlist = [];
  int _currentIndex = -1;

  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  // Initialize the player
  Future<void> init() async {
    // Set up audio player event listeners
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });
  }

  // Load a playlist and start playing
  Future<void> loadPlaylist(
    List<SongModel> songs, {
    int initialIndex = 0,
  }) async {
    _playlist = songs;
    if (songs.isNotEmpty && initialIndex >= 0 && initialIndex < songs.length) {
      _currentIndex = initialIndex;
      await playSong(songs[initialIndex]);
    }
  }

  Future<void> playSong(SongModel song) async {
    try {
      // Find index of song in playlist
      final index = _playlist.indexWhere((s) => s.id == song.id);
      if (index != -1) {
        _currentIndex = index;
      }

      // Check if URI is valid
      if (song.uri != null) {
        // Use setUrl directly with the song URI
        await _audioPlayer.setUrl(song.uri!);

        // Start playback
        await _audioPlayer.play();
      } else {
        print("Song URI is null");
      }
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  // Basic playback controls
  Future<void> play() => _audioPlayer.play();
  Future<void> pause() => _audioPlayer.pause();
  Future<void> stop() => _audioPlayer.stop();
  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  // Skip to next song
  Future<void> next() async {
    if (_playlist.isEmpty) return;

    final nextIndex = (_currentIndex + 1) % _playlist.length;
    _currentIndex = nextIndex;
    await playSong(_playlist[nextIndex]);
  }

  // Skip to previous song
  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    final previousIndex =
        _currentIndex - 1 < 0 ? _playlist.length - 1 : _currentIndex - 1;
    _currentIndex = previousIndex;
    await playSong(_playlist[previousIndex]);
  }

  // Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await pause();
    } else {
      await play();
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
