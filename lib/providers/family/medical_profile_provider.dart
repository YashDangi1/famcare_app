import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/medical_profile.dart';
import '../../services/family/medical_profile_service.dart';

final medicalProfileServiceProvider = Provider((ref) {
  return MedicalProfileService(Supabase.instance.client);
});

final medicalProfileProvider = FutureProvider.family<MedicalProfile?, String>((ref, userId) async {
  return ref.watch(medicalProfileServiceProvider).getProfile(userId);
});
