// models/song_model.dart
// Note: This is an optional additional model class if you want to extend the functionality
// beyond what on_audio_query provides with its SongModel

import 'package:on_audio_query/on_audio_query.dart';

class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final Duration duration;
  final String? artworkPath;
  bool isFavorite;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    this.artworkPath,
    this.isFavorite = false,
  });

  // Create from on_audio_query SongModel
  factory Song.fromSongModel(SongModel model) {
    return Song(
      id: model.id,
      title: model.title,
      artist: model.artist ?? 'Unknown Artist',
      album: model.album ?? 'Unknown Album',
      path: model.data,
      duration: Duration(milliseconds: model.duration ?? 0),
      isFavorite: false,
    );
  }

  // Toggle favorite status
  void toggleFavorite() {
    isFavorite = !isFavorite;
  }

  // Copy with method for immutability
  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    String? path,
    Duration? duration,
    String? artworkPath,
    bool? isFavorite,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      artworkPath: artworkPath ?? this.artworkPath,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
