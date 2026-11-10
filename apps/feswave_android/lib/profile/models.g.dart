// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Track _$TrackFromJson(Map<String, dynamic> json) => _Track(
  trackId: (json['trackId'] as num).toInt(),
  artistName: json['artistName'] as String,
  trackName: json['trackName'] as String,
  collectionName: json['collectionName'] as String? ?? '',
  artworkUrl: json['artworkUrl'] as String?,
  trackUrl: json['trackUrl'] as String?,
);

Map<String, dynamic> _$TrackToJson(_Track instance) => <String, dynamic>{
  'trackId': instance.trackId,
  'artistName': instance.artistName,
  'trackName': instance.trackName,
  'collectionName': instance.collectionName,
  'artworkUrl': instance.artworkUrl,
  'trackUrl': instance.trackUrl,
};

_Profile _$ProfileFromJson(Map<String, dynamic> json) => _Profile(
  name: json['name'] as String? ?? '',
  color: json['color'] as String? ?? 'pink',
  artist: json['artist'] as String? ?? '',
  song: json['song'] as String? ?? '',
  visible: json['visible'] as bool? ?? false,
  tracks:
      (json['tracks'] as List<dynamic>?)
          ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  favoriteTrackId: (json['favoriteTrackId'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProfileToJson(_Profile instance) => <String, dynamic>{
  'name': instance.name,
  'color': instance.color,
  'artist': instance.artist,
  'song': instance.song,
  'visible': instance.visible,
  'tracks': instance.tracks,
  'favoriteTrackId': instance.favoriteTrackId,
};
