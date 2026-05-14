import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/medicine_model.dart';

class PrescriptionService {
  // Fetch Gemini API Key from .env
  final String? apiKey = dotenv.env['GEMINI_KEY'];

  Future<List<Medicine>> parseWithAI(String text) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception("Gemini API key not configured in .env file");
    }

    if (text.trim().isEmpty) throw Exception("Empty OCR text");

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey",
    );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": "Extract medicine information from this text. Return ONLY a JSON array with these keys: 'name', 'dose', 'morning' (0 or 1), 'afternoon' (0 or 1), 'night' (0 or 1), 'instructions'. Text: $text"
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data["candidates"][0]["content"]["parts"][0]["text"];
        
        // Clean JSON
        content = content.replaceAll("```json", "").replaceAll("```", "").trim();
        final List parsed = jsonDecode(content);
        return parsed.map((e) => Medicine.fromJson(e)).toList();
      } else {
        throw Exception("AI Parsing failed");
      }
    } catch (e) {
      // Fallback: Handle manual entry if AI parsing fails
      return [Medicine(name: "Manual Entry Required", dose: "-", morning: 0, afternoon: 0, night: 0, instructions: "Could not parse automatically")];
    }
  }
}