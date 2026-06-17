import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class DiagnosticHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final responseBody = jsonEncode({
      'access_token': 'mock-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'mock-refresh-token',
      'user': {
        'id': 'mock-user-uuid-123',
        'aud': 'authenticated',
        'email': 'test@famcare.com',
        'role': 'authenticated',
      }
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('Diagnose Supabase Auth Storage Key', () async {
    SharedPreferences.setMockInitialValues({});
    
    await Supabase.initialize(
      url: 'http://10.0.2.2:8080',
      anonKey: 'dummy-anon-key',
      httpClient: DiagnosticHttpClient(),
    );

    final client = Supabase.instance.client;
    await client.auth.signInWithPassword(email: 'test@famcare.com', password: 'password123');
    
    final prefs = await SharedPreferences.getInstance();
    print("SP Keys written: ${prefs.getKeys()}");
    for (final key in prefs.getKeys()) {
      print("  $key => ${prefs.get(key)}");
    }
  });
}
