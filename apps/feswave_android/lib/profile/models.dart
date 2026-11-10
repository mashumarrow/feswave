import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
abstract class Track with _$Track {
  const factory Track({
    required int trackId,
    required String artistName,
    required String trackName,
    @Default('') String collectionName,
    String? artworkUrl,
    String? trackUrl,
  }) = _Track;
  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
}

@freezed
abstract class Profile with _$Profile {
  const Profile._();
  const factory Profile({
    @Default('') String name,
    @Default('pink') String color,
    @Default('') String artist,
    @Default('') String song,
    @Default(false) bool visible,
    @Default([]) List<Track> tracks,
    int? favoriteTrackId,
  }) = _Profile;
  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
  Track? get favorite =>
      tracks.where((t) => t.trackId == favoriteTrackId).firstOrNull;
  Profile get publicView => visible ? this : Profile(name: name, color: color);
}
