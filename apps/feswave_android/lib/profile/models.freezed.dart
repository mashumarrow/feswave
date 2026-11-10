// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Track {

 int get trackId; String get artistName; String get trackName; String get collectionName; String? get artworkUrl; String? get trackUrl;
/// Create a copy of Track
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackCopyWith<Track> get copyWith => _$TrackCopyWithImpl<Track>(this as Track, _$identity);

  /// Serializes this Track to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Track&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.collectionName, collectionName) || other.collectionName == collectionName)&&(identical(other.artworkUrl, artworkUrl) || other.artworkUrl == artworkUrl)&&(identical(other.trackUrl, trackUrl) || other.trackUrl == trackUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,trackId,artistName,trackName,collectionName,artworkUrl,trackUrl);

@override
String toString() {
  return 'Track(trackId: $trackId, artistName: $artistName, trackName: $trackName, collectionName: $collectionName, artworkUrl: $artworkUrl, trackUrl: $trackUrl)';
}


}

/// @nodoc
abstract mixin class $TrackCopyWith<$Res>  {
  factory $TrackCopyWith(Track value, $Res Function(Track) _then) = _$TrackCopyWithImpl;
@useResult
$Res call({
 int trackId, String artistName, String trackName, String collectionName, String? artworkUrl, String? trackUrl
});




}
/// @nodoc
class _$TrackCopyWithImpl<$Res>
    implements $TrackCopyWith<$Res> {
  _$TrackCopyWithImpl(this._self, this._then);

  final Track _self;
  final $Res Function(Track) _then;

/// Create a copy of Track
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? trackId = null,Object? artistName = null,Object? trackName = null,Object? collectionName = null,Object? artworkUrl = freezed,Object? trackUrl = freezed,}) {
  return _then(_self.copyWith(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,collectionName: null == collectionName ? _self.collectionName : collectionName // ignore: cast_nullable_to_non_nullable
as String,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,trackUrl: freezed == trackUrl ? _self.trackUrl : trackUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Track].
extension TrackPatterns on Track {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Track value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Track() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Track value)  $default,){
final _that = this;
switch (_that) {
case _Track():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Track value)?  $default,){
final _that = this;
switch (_that) {
case _Track() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int trackId,  String artistName,  String trackName,  String collectionName,  String? artworkUrl,  String? trackUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Track() when $default != null:
return $default(_that.trackId,_that.artistName,_that.trackName,_that.collectionName,_that.artworkUrl,_that.trackUrl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int trackId,  String artistName,  String trackName,  String collectionName,  String? artworkUrl,  String? trackUrl)  $default,) {final _that = this;
switch (_that) {
case _Track():
return $default(_that.trackId,_that.artistName,_that.trackName,_that.collectionName,_that.artworkUrl,_that.trackUrl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int trackId,  String artistName,  String trackName,  String collectionName,  String? artworkUrl,  String? trackUrl)?  $default,) {final _that = this;
switch (_that) {
case _Track() when $default != null:
return $default(_that.trackId,_that.artistName,_that.trackName,_that.collectionName,_that.artworkUrl,_that.trackUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Track implements Track {
  const _Track({required this.trackId, required this.artistName, required this.trackName, this.collectionName = '', this.artworkUrl, this.trackUrl});
  factory _Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

@override final  int trackId;
@override final  String artistName;
@override final  String trackName;
@override@JsonKey() final  String collectionName;
@override final  String? artworkUrl;
@override final  String? trackUrl;

/// Create a copy of Track
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackCopyWith<_Track> get copyWith => __$TrackCopyWithImpl<_Track>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Track&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.collectionName, collectionName) || other.collectionName == collectionName)&&(identical(other.artworkUrl, artworkUrl) || other.artworkUrl == artworkUrl)&&(identical(other.trackUrl, trackUrl) || other.trackUrl == trackUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,trackId,artistName,trackName,collectionName,artworkUrl,trackUrl);

@override
String toString() {
  return 'Track(trackId: $trackId, artistName: $artistName, trackName: $trackName, collectionName: $collectionName, artworkUrl: $artworkUrl, trackUrl: $trackUrl)';
}


}

/// @nodoc
abstract mixin class _$TrackCopyWith<$Res> implements $TrackCopyWith<$Res> {
  factory _$TrackCopyWith(_Track value, $Res Function(_Track) _then) = __$TrackCopyWithImpl;
@override @useResult
$Res call({
 int trackId, String artistName, String trackName, String collectionName, String? artworkUrl, String? trackUrl
});




}
/// @nodoc
class __$TrackCopyWithImpl<$Res>
    implements _$TrackCopyWith<$Res> {
  __$TrackCopyWithImpl(this._self, this._then);

  final _Track _self;
  final $Res Function(_Track) _then;

/// Create a copy of Track
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? artistName = null,Object? trackName = null,Object? collectionName = null,Object? artworkUrl = freezed,Object? trackUrl = freezed,}) {
  return _then(_Track(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,collectionName: null == collectionName ? _self.collectionName : collectionName // ignore: cast_nullable_to_non_nullable
as String,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,trackUrl: freezed == trackUrl ? _self.trackUrl : trackUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Profile {

 String get name; String get color; String get artist; String get song; bool get visible; List<Track> get tracks; int? get favoriteTrackId;
/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileCopyWith<Profile> get copyWith => _$ProfileCopyWithImpl<Profile>(this as Profile, _$identity);

  /// Serializes this Profile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Profile&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.song, song) || other.song == song)&&(identical(other.visible, visible) || other.visible == visible)&&const DeepCollectionEquality().equals(other.tracks, tracks)&&(identical(other.favoriteTrackId, favoriteTrackId) || other.favoriteTrackId == favoriteTrackId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,color,artist,song,visible,const DeepCollectionEquality().hash(tracks),favoriteTrackId);

@override
String toString() {
  return 'Profile(name: $name, color: $color, artist: $artist, song: $song, visible: $visible, tracks: $tracks, favoriteTrackId: $favoriteTrackId)';
}


}

/// @nodoc
abstract mixin class $ProfileCopyWith<$Res>  {
  factory $ProfileCopyWith(Profile value, $Res Function(Profile) _then) = _$ProfileCopyWithImpl;
@useResult
$Res call({
 String name, String color, String artist, String song, bool visible, List<Track> tracks, int? favoriteTrackId
});




}
/// @nodoc
class _$ProfileCopyWithImpl<$Res>
    implements $ProfileCopyWith<$Res> {
  _$ProfileCopyWithImpl(this._self, this._then);

  final Profile _self;
  final $Res Function(Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? color = null,Object? artist = null,Object? song = null,Object? visible = null,Object? tracks = null,Object? favoriteTrackId = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,song: null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as String,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,tracks: null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<Track>,favoriteTrackId: freezed == favoriteTrackId ? _self.favoriteTrackId : favoriteTrackId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Profile].
extension ProfilePatterns on Profile {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Profile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Profile value)  $default,){
final _that = this;
switch (_that) {
case _Profile():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Profile value)?  $default,){
final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String color,  String artist,  String song,  bool visible,  List<Track> tracks,  int? favoriteTrackId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that.name,_that.color,_that.artist,_that.song,_that.visible,_that.tracks,_that.favoriteTrackId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String color,  String artist,  String song,  bool visible,  List<Track> tracks,  int? favoriteTrackId)  $default,) {final _that = this;
switch (_that) {
case _Profile():
return $default(_that.name,_that.color,_that.artist,_that.song,_that.visible,_that.tracks,_that.favoriteTrackId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String color,  String artist,  String song,  bool visible,  List<Track> tracks,  int? favoriteTrackId)?  $default,) {final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that.name,_that.color,_that.artist,_that.song,_that.visible,_that.tracks,_that.favoriteTrackId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Profile extends Profile {
  const _Profile({this.name = '', this.color = 'pink', this.artist = '', this.song = '', this.visible = false, final  List<Track> tracks = const [], this.favoriteTrackId}): _tracks = tracks,super._();
  factory _Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String color;
@override@JsonKey() final  String artist;
@override@JsonKey() final  String song;
@override@JsonKey() final  bool visible;
 final  List<Track> _tracks;
@override@JsonKey() List<Track> get tracks {
  if (_tracks is EqualUnmodifiableListView) return _tracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tracks);
}

@override final  int? favoriteTrackId;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileCopyWith<_Profile> get copyWith => __$ProfileCopyWithImpl<_Profile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Profile&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.song, song) || other.song == song)&&(identical(other.visible, visible) || other.visible == visible)&&const DeepCollectionEquality().equals(other._tracks, _tracks)&&(identical(other.favoriteTrackId, favoriteTrackId) || other.favoriteTrackId == favoriteTrackId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,color,artist,song,visible,const DeepCollectionEquality().hash(_tracks),favoriteTrackId);

@override
String toString() {
  return 'Profile(name: $name, color: $color, artist: $artist, song: $song, visible: $visible, tracks: $tracks, favoriteTrackId: $favoriteTrackId)';
}


}

/// @nodoc
abstract mixin class _$ProfileCopyWith<$Res> implements $ProfileCopyWith<$Res> {
  factory _$ProfileCopyWith(_Profile value, $Res Function(_Profile) _then) = __$ProfileCopyWithImpl;
@override @useResult
$Res call({
 String name, String color, String artist, String song, bool visible, List<Track> tracks, int? favoriteTrackId
});




}
/// @nodoc
class __$ProfileCopyWithImpl<$Res>
    implements _$ProfileCopyWith<$Res> {
  __$ProfileCopyWithImpl(this._self, this._then);

  final _Profile _self;
  final $Res Function(_Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? color = null,Object? artist = null,Object? song = null,Object? visible = null,Object? tracks = null,Object? favoriteTrackId = freezed,}) {
  return _then(_Profile(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,song: null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as String,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,tracks: null == tracks ? _self._tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<Track>,favoriteTrackId: freezed == favoriteTrackId ? _self.favoriteTrackId : favoriteTrackId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
