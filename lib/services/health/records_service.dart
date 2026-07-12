import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/health/health_record.dart';
import '../activity_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class RecordsService {
  final _supabase = Supabase.instance.client;

  Future<List<HealthRecord>> listRecords({String? userId, String? category}) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final uid = userId ?? currentUserId;
    if (uid == null) return [];

    if (userId != null && userId != currentUserId) {
      try {
        final hasPermission = await _supabase.rpc('can_view_health_module', params: {
          'p_target_user_id': userId,
          'p_module': 'records'
        });
        if (hasPermission != true) {
          throw Exception('PERMISSION_DENIED');
        }
      } catch (e) {
        if (e.toString().contains('PERMISSION_DENIED')) rethrow;
        // Fallback to RLS
      }
    }

    var query = _supabase.from('health_records').select().eq('user_id', uid);

    if (category != null && category.isNotEmpty && category != 'All') {
      // Map category strings if needed, or assume they match the DB exactly
      // DB check constraint: ('prescription', 'lab_report', 'imaging', 'discharge_summary', 'doctor_note', 'vaccine', 'other')
      query = query.eq('category', category.toLowerCase().replaceAll(' ', '_'));
    }

    final response = await query.order('record_date', ascending: false, nullsFirst: false);
    return (response as List).map((json) => HealthRecord.fromJson(json)).toList();
  }

  Future<HealthRecord> uploadRecord(HealthRecord record, File file) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('User not logged in');

    final fileExt = path.extension(file.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
    final storagePath = '$uid/records/$fileName';

    await _supabase.storage.from('health_documents').upload(storagePath, file);
    final fileUrl = _supabase.storage.from('health_documents').getPublicUrl(storagePath);

    final newRecord = HealthRecord(
      id: record.id,
      userId: record.userId.isEmpty ? uid : record.userId,
      category: record.category.toLowerCase().replaceAll(' ', '_'),
      title: record.title,
      fileUrl: fileUrl,
      providerName: record.providerName,
      recordDate: record.recordDate,
      tags: record.tags,
      linkedAppointmentId: record.linkedAppointmentId,
      source: record.source,
    );

    final response = await _supabase.from('health_records').insert(newRecord.toJson()).select().maybeSingle();

    if (response == null) {
      throw Exception('Failed to insert record');
    }

    final createdRecord = HealthRecord.fromJson(response);

    try {
      await ActivityService.log(
        actionType: 'RECORD_UPLOADED',
        description: 'Uploaded a new health record: ${createdRecord.title}',
      );
    } catch (e) {
      debugPrint('Log activity error: $e');
    }

    return createdRecord;
  }

  Future<HealthRecord> updateRecord(HealthRecord record) async {
    if (record.id == null) {
      throw Exception('Cannot update record without an ID');
    }

    final json = record.toJson();
    json.remove('id');
    json['updated_at'] = DateTime.now().toUtc().toIso8601String();
    
    // Ensure category is formatted correctly
    if (json['category'] != null) {
       json['category'] = json['category'].toString().toLowerCase().replaceAll(' ', '_');
    }

    final response = await _supabase.from('health_records').update(json).eq('id', record.id!).select().maybeSingle();
    
    if (response == null) {
      throw Exception('Failed to update record');
    }

    return HealthRecord.fromJson(response);
  }

  Future<void> deleteRecord(String id) async {
    // 1. Fetch record to get fileUrl
    final recordResponse = await _supabase
        .from('health_records')
        .select('file_url')
        .eq('id', id)
        .maybeSingle();

    if (recordResponse != null && recordResponse['file_url'] != null) {
      final String fileUrl = recordResponse['file_url'];
      // fileUrl format: https://[project].supabase.co/storage/v1/object/public/health_documents/[userId]/records/[fileName]
      // We need to extract: [userId]/records/[fileName]
      final uri = Uri.tryParse(fileUrl);
      if (uri != null) {
        final pathSegments = uri.pathSegments;
        final docsIndex = pathSegments.indexOf('health_documents');
        if (docsIndex != -1 && docsIndex < pathSegments.length - 1) {
          final storagePath = pathSegments.sublist(docsIndex + 1).join('/');
          try {
            await _supabase.storage.from('health_documents').remove([storagePath]);
          } catch (e) {
            debugPrint('Failed to delete file from storage: $e');
          }
        }
      }
    }

    // 2. Delete record from DB
    await _supabase.from('health_records').delete().eq('id', id);
  }
}
