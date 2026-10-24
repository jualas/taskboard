import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_taskboard/core/error/exceptions.dart';
import 'package:personal_taskboard/features/auth/data/datasources/auth_remote_data_source.dart';

void main() {
  AuthRemoteDataSourceImpl build(MockClientHandler handler) =>
      AuthRemoteDataSourceImpl(
        baseUrl: 'https://api.test/',
        client: MockClient(handler),
      );

  test('login parsea token y usuario', () async {
    late http.Request sent;
    final ds = build((req) async {
      sent = req;
      return http.Response(
        jsonEncode({
          'access_token': 'jwt',
          'user': {'id': 'u1', 'email': 'u@test.com'},
        }),
        200,
      );
    });

    final session = await ds.login('u@test.com', 'pw');

    expect(sent.url.toString(), 'https://api.test/auth/login');
    expect(jsonDecode(sent.body), {'email': 'u@test.com', 'password': 'pw'});
    expect(session.accessToken, 'jwt');
    expect(session.userId, 'u1');
  });

  test('login con 401 lanza UnauthorizedException', () {
    final ds = build((_) async => http.Response('', 401));
    expect(
      () => ds.login('u@test.com', 'mal'),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('login con respuesta sin token lanza ServerException', () {
    final ds = build((_) async => http.Response(jsonEncode({'user': {}}), 200));
    expect(() => ds.login('u@test.com', 'pw'), throwsA(isA<ServerException>()));
  });

  test('changePassword manda el Bearer', () async {
    late http.Request sent;
    final ds = build((req) async {
      sent = req;
      return http.Response('', 204);
    });

    await ds.changePassword(
      accessToken: 'jwt',
      currentPassword: 'a',
      newPassword: 'b',
    );

    expect(sent.url.path, '/auth/change-password');
    expect(sent.headers['Authorization'], 'Bearer jwt');
  });
}
