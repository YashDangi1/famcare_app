import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final supabase = Supabase.instance.client;

  Future<void> insertMedicines(List<Map<String, dynamic>> medicines) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint("DB ERROR: No authenticated user");
        return;
      }
      // Add user_id to each medicine
      final dataToInsert = medicines.map((m) => {...m, 'user_id': userId}).toList();

      await supabase.from('medications').insert(dataToInsert);
    } catch (e) {
      debugPrint("DB ERROR: $e");
    }
  }
}