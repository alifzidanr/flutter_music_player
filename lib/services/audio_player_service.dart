// lib/services/audio_player_service.dart

import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';

class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _currentSongController = StreamController<SongModel?>.broadcast();
  
  // Event streams
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<SongModel?> get currentSongStream => _currentSongController.stream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  // Current playback state
  bool get isPlaying => _audioPlayer.playing;
  Duration get duration => _audioPlayer.duration ?? Duration.zero;
  Duration get position => _audioPlayer.position;

  // Playlist management
  List<SongModel> _playlist = [];
  int _currentIndex = -1;
  
  // Notification setup
  late AudioHandler _audioHandler;
  bool _isAudioHandlerInitialized = false;

  // Current song getter
  SongModel? _currentSong;
  SongModel? get currentSong => _currentSong;

  // Initialize the player
  Future<void> init() async {
    // Set up audio player event listeners
    _audioPlayer.playerStateStream.listen((state) {
      // Forward state to our controller
      _playerStateController.add(state);
      
      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });
    
    // Initialize audio service for notifications
    await _initAudioService();
  }
  
  Future<void> _initAudioService() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(_audioPlayer),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.flutter_music_player.channel.audio',
          androidNotificationChannelName: 'Music Player',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      _isAudioHandlerInitialized = true;
      print("Audio service initialized successfully");
    } catch (e) {
      print("Error initializing audio service: $e");
    }
  }

  // Update current song and notify listeners
  void _updateCurrentSong(SongModel? song) {
    _currentSong = song;
    _currentSongController.add(song);
    
    if (song != null) {
      _updateMediaItem(song);
    }
  }

  // Load a playlist for the player
  Future<void> loadPlaylist(
    List<SongModel> songs, {
    int initialIndex = 0,
    bool autoPlay = true,
  }) async {
    print("Loading playlist with ${songs.length} songs, initial index: $initialIndex");
    
    if (songs.isEmpty) {
      print("WARNING: Empty playlist provided");
      return;
    }
    
    if (initialIndex < 0 || initialIndex >= songs.length) {
      print("WARNING: Invalid initial index: $initialIndex (playlist size: ${songs.length})");
      initialIndex = 0; // Reset to a valid index
    }
    
    // Create a copy of the songs list to avoid reference issues
    _playlist = List.from(songs);
    _currentIndex = initialIndex;
    
    print("Playlist loaded with ${_playlist.length} songs, current index: $_currentIndex");
    print("Initial song: ${_playlist[initialIndex].title} (ID: ${_playlist[initialIndex].id})");
    
    // Update current song immediately
    _updateCurrentSong(_playlist[initialIndex]);
    
    if (autoPlay) {
      await playSong(_playlist[initialIndex]);
    }
  }

  Future<void> playSong(SongModel song) async {
    try {
      print("Attempting to play song: ${song.title} (ID: ${song.id})");
      
      // If this song isn't in the playlist yet, add it
      if (_playlist.isEmpty || !_playlist.any((s) => s.id == song.id)) {
        _playlist = [song];
        _currentIndex = 0;
      } else {
        // Find index of song in playlist
        final index = _playlist.indexWhere((s) => s.id == song.id);
        print("Found song index in playlist: $index");
        
        if (index != -1) {
          _currentIndex = index;
          print("Current index set to: $_currentIndex");
        } else {
          print("WARNING: Song not found in playlist");
        }
      }
      
      // Update current song immediately with the exact song object passed
      _updateCurrentSong(song);

      // Check if URI is valid
      if (song.uri != null) {
        print("Setting URL: ${song.uri}");
        // Use setUrl directly with the song URI
        await _audioPlayer.setUrl(song.uri!);

        // Start playback
        await play();
        
        print("Now playing: ${song.title}");
      } else {
        print("ERROR: Song URI is null");
      }
    } catch (e) {
      print("ERROR playing song: $e");
    }
  }
  
  void _updateMediaItem(SongModel song) {
    if (!_isAudioHandlerInitialized) return;
    
    // Update the notification with song info
    final mediaItem = MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      duration: Duration(milliseconds: song.duration ?? 0),
    );
    
    // In newer versions of audio_service, we need to use setMediaItem instead of add
    (_audioHandler as MyAudioHandler).setMediaItem(mediaItem);
  }

  // Basic playback controls
  Future<void> play() async {
    await _audioPlayer.play();
    if (_isAudioHandlerInitialized) {
      await _audioHandler.play();
    }
  }
  
  Future<void> pause() async {
    await _audioPlayer.pause();
    if (_isAudioHandlerInitialized) {
      await _audioHandler.pause();
    }
  }
  
  Future<void> stop() async {
    await _audioPlayer.stop();
    if (_isAudioHandlerInitialized) {
      await _audioHandler.stop();
    }
    
    // Clear current song when stopped
    _updateCurrentSong(null);
  }
  
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
    if (_isAudioHandlerInitialized) {
      await _audioHandler.seek(position);
    }
  }

 // Fix for the next/previous buttons in audio_player_service.dart
// Replace the current next() and previous() methods with these:

  // Skip to next song - Direct implementation
  Future<void> next() async {
    if (_playlist.isEmpty || _playlist.length <= 1) {
      print("Cannot skip: Empty playlist or only one song");
      return;
    }
    
    try {
      // Calculate next index with wraparound
      final nextIndex = (_currentIndex + 1) % _playlist.length;
      print("Attempting to play next song at index $nextIndex");
      
      // Directly play the song at the new index
      final nextSong = _playlist[nextIndex];
      
      // Store the new index first
      _currentIndex = nextIndex;
      
      // Update current song immediately for UI updates
      _updateCurrentSong(nextSong);
      
      if (nextSong.uri == null) {
        print("ERROR: Next song URI is null");
        return;
      }
      
      // Stop the current playback
      await _audioPlayer.stop();
      
      // Set the new URL and play
      await _audioPlayer.setUrl(nextSong.uri!);
      await _audioPlayer.play();
      
      print("Playing next song: ${nextSong.title}");
    } catch (e) {
      print("ERROR in next(): $e");
    }
  }

  // Skip to previous song - Direct implementation
  Future<void> previous() async {
    if (_playlist.isEmpty || _playlist.length <= 1) {
      print("Cannot skip: Empty playlist or only one song");
      return;
    }
    
    try {
      // Calculate previous index with wraparound
      final prevIndex = _currentIndex > 0 ? _currentIndex - 1 : _playlist.length - 1;
      print("Attempting to play previous song at index $prevIndex");
      
      // Directly play the song at the new index
      final prevSong = _playlist[prevIndex];
      
      // Store the new index first
      _currentIndex = prevIndex;
      
      // Update current song immediately for UI updates
      _updateCurrentSong(prevSong);
      
      if (prevSong.uri == null) {
        print("ERROR: Previous song URI is null");
        return;
      }
      
      // Stop the current playback
      await _audioPlayer.stop();
      
      // Set the new URL and play
      await _audioPlayer.setUrl(prevSong.uri!);
      await _audioPlayer.play();
      
      print("Playing previous song: ${prevSong.title}");
    } catch (e) {
      print("ERROR in previous(): $e");
    }
  }
  
  // Add this method to ensure the playlist is loaded correctly before playing
  Future<void> ensurePlaylistLoaded(List<SongModel> songs, int initialIndex) async {
    if (_playlist.isEmpty) {
      print("Loading playlist for the first time");
      await loadPlaylist(songs, initialIndex: initialIndex, autoPlay: false);
    }
  }

  // Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await pause();
    } else {
      await play();
    }
  }

  // Public method to update current song
  void updateCurrentSong(SongModel? song) {
    _updateCurrentSong(song);
  }
  
  // Public method to set current index
  void setCurrentIndex(int index) {
    _currentIndex = index;
  }
  
  // Public method for direct playback control
  Future<void> playDirectly(SongModel song) async {
    try {
      // Update current song immediately for UI updates
      _updateCurrentSong(song);
      
      if (song.uri == null) {
        print("ERROR: Song URI is null");
        return;
      }
      
      // Stop the current playback
      await _audioPlayer.stop();
      
      // Set the new URL and play
      await _audioPlayer.setUrl(song.uri!);
      await _audioPlayer.play();
      
      print("Playing song directly: ${song.title}");
    } catch (e) {
      print("ERROR in playDirectly(): $e");
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _playerStateController.close();
    await _currentSongController.close();
    if (_isAudioHandlerInitialized) {
      await _audioHandler.stop();
    }
  }
}

// Audio handler for background playback and notifications
class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;
  
  MyAudioHandler(this.player) {
    // Forward player events to clients
    player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: event.currentIndex,
      ));
    });
  }
  
  // Set the current media item for notification
  void setMediaItem(MediaItem item) {
    mediaItem.add(item);
  }

  // Handle play request
  @override
  Future<void> play() => player.play();

  // Handle pause request
  @override
  Future<void> pause() => player.pause();

  // Handle stop request
  @override
  Future<void> stop() async {
    await player.stop();
    return super.stop();
  }

  // Handle seek request
  @override
  Future<void> seek(Duration position) => player.seek(position);

  // Handle skip to next
  @override
  Future<void> skipToNext() => player.seekToNext();

  // Handle skip to previous
  @override
  Future<void> skipToPrevious() => player.seekToPrevious();
}