import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';

class CookieStorage implements Storage {
  final secure = const FlutterSecureStorage();
  String key(String k) => 'feswave.cookie.${base64Url.encode(utf8.encode(k))}';
  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}
  @override
  Future<String?> read(String k) => secure.read(key: key(k));
  @override
  Future<void> write(String k, String value) =>
      secure.write(key: key(k), value: value);
  @override
  Future<void> delete(String k) => secure.delete(key: key(k));
  @override
  Future<void> deleteAll(List<String> keys) => Future.wait(keys.map(delete));
}

class ProfileApi {
  static const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000/api/',
  );
  final dio = Dio(
    BaseOptions(
      baseUrl: base.endsWith('/') ? base : '$base/',
      followRedirects: false,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  ProfileApi() {
    dio.interceptors.add(
      CookieManager(PersistCookieJar(storage: CookieStorage())),
    );
  }
  Future<Map<String, dynamic>> session() async =>
      (await dio.get<Map<String, dynamic>>('session')).data!;
  Future<List<Track>> search(String term, CancelToken token) async {
    await session();
    final res = await dio.get(
      'music/search',
      queryParameters: {'term': term},
      cancelToken: token,
    );
    return (res.data['results'] as List)
        .map((v) => Track.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  Future<Profile> save(Profile p) async {
    final r = await dio.put(
      'profile',
      data: {
        ...p.toJson()..remove("tracks"),
        'trackIds': p.tracks.map((t) => t.trackId).toList(),
      },
    );
    return Profile.fromJson(r.data as Map<String, dynamic>);
  }

  Options get auth => Options(headers: {'X-Feswave-Auth': '1'});
  Future<Profile> login(Profile local) async {
    final s = await session();
    if (s['account']['google'] == true) return Profile.fromJson(s['user']);
    final clientId = s['google']?['clientId'];
    if (clientId == null) throw StateError('サーバーにGoogleクライアントIDを設定してください');
    if (local.name.isNotEmpty) await save(local);
    final challenge = await dio.post('auth/challenge', options: auth);
    final credential = await const MethodChannel('jp.feswave/identity')
        .invokeMethod<String>('google', {
          'clientId': clientId,
          'nonce': challenge.data['nonce'],
        });
    final r = await dio.post(
      'auth/google',
      options: auth,
      data: {'idToken': credential},
    );
    return Profile.fromJson(r.data['user']);
  }

  Future<void> logout() async {
    await dio.post('auth/logout', options: auth);
  }
}
