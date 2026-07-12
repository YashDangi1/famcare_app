import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/health/appointment_note.dart';
import '../../models/health/appointment.dart';
import '../activity_service.dart';

class AppointmentsService {
  final _supabase = Supabase.instance.client;

  Future<List<Appointment>> listAppointments({String? userId, String? status}) async {
    final uid = userId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    dynamic query = _supabase.from('appointments').select().eq('user_id', uid);
    
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    
    // Default order: Upcoming appointments earliest first, completed appointments latest first
    if (status == 'upcoming') {
      query = query.order('appointment_date', ascending: true);
    } else {
      query = query.order('appointment_date', ascending: false);
    }

    final response = await query;
    return (response as List).map((json) => Appointment.fromJson(json)).toList();
  }

  Future<Appointment> createAppointment(Appointment appointment) async {
    final response = await _supabase.from('appointments').insert(appointment.toJson()).select().maybeSingle();
    
    if (response == null) {
      throw Exception('Failed to create appointment');
    }
    
    return Appointment.fromJson(response);
  }

  Future<Appointment> updateAppointment(Appointment appointment) async {
    final json = appointment.toJson();
    json['updated_at'] = DateTime.now().toUtc().toIso8601String();
    
    final response = await _supabase.from('appointments').update(json).eq('id', appointment.id).select().maybeSingle();
    
    if (response == null) {
      throw Exception('Failed to update appointment');
    }
    
    return Appointment.fromJson(response);
  }

  Future<void> deleteAppointment(String id) async {
    await _supabase.from('appointments').delete().eq('id', id);
  }

  Future<AppointmentNote?> getAppointmentNote(String appointmentId) async {
    final response = await _supabase.from('appointment_notes').select().eq('appointment_id', appointmentId).maybeSingle();
    if (response == null) return null;
    return AppointmentNote.fromJson(response);
  }

  Future<AppointmentNote> upsertAppointmentNote(AppointmentNote note) async {
    final json = note.toJson();
    json['updated_at'] = DateTime.now().toUtc().toIso8601String();
    
    final response = await _supabase.from('appointment_notes').upsert(
      json,
      onConflict: 'appointment_id'
    ).select().maybeSingle();
    
    if (response == null) {
      throw Exception('Failed to upsert appointment note');
    }
    
    return AppointmentNote.fromJson(response);
  }

  Future<Appointment> markAppointmentCompleted(String id) async {
    final response = await _supabase.from('appointments').update({
      'status': 'completed',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).select().maybeSingle();
    
    if (response == null) {
      throw Exception('Failed to mark appointment completed');
    }
    
    final appt = Appointment.fromJson(response);
    
    try {
      await ActivityService.log(
        actionType: 'APPOINTMENT_COMPLETED',
        description: 'Completed visit with ${appt.doctorName}',
      );
    } catch (e) {
      // Ignore
    }

    return appt;
  }
}
