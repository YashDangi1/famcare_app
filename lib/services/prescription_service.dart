import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/medicine_model.dart';

class PrescriptionService {
  final http.Client? httpClient;

  PrescriptionService({this.httpClient});

  Future<List<Medicine>> parseWithAI(String text) async {
    final String? apiKey = dotenv.env['GEMINI_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Gemini key not configured in .env file");
    }

    if (text.trim().isEmpty) throw Exception("Empty OCR text");

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent",
    );

    final client = httpClient ?? http.Client();
    final response = await client
        .post(
          url,
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {
                    "text":
                        "Extract medicine information from this text. Return ONLY a JSON array with these keys: 'name', 'dosage', 'frequency' (1, 2, or 3), 'time1' (e.g. 08:00 AM), 'time2' (if frequency > 1), 'time3' (if frequency > 2), 'duration_days' (integer), 'qty' (total pills). Text: $text"
                  }
                ]
              }
            ]
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
          "AI Parsing failed (${response.statusCode}): ${response.body}");
    }

    final data = jsonDecode(response.body);

    // Validate response structure before accessing
    final candidates = data["candidates"] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception("AI returned no candidates");
    }
    final content = candidates[0]?["content"]?["parts"]?[0]?["text"] as String?;
    if (content == null || content.isEmpty) {
      throw Exception("AI returned empty content");
    }

    // Clean JSON
    final cleaned = content.replaceAll("```json", "").replaceAll("```", "").trim();
    final List parsed = jsonDecode(cleaned);

    if (parsed.isEmpty) {
      throw Exception("AI found no medicines in the text");
    }

    return parsed.map((e) => Medicine.fromJson(e)).toList();
  }
}
