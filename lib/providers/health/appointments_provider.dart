import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/health/appointments_service.dart';
import '../../models/health/appointment.dart';
import '../../models/health/appointment_note.dart';

final appointmentsServiceProvider = Provider((ref) => AppointmentsService());

final appointmentsProvider = StateNotifierProvider<AppointmentsNotifier, AsyncValue<List<Appointment>>>((ref) {
  final service = ref.watch(appointmentsServiceProvider);
  return AppointmentsNotifier(service);
});

class AppointmentsNotifier extends StateNotifier<AsyncValue<List<Appointment>>> {
  final AppointmentsService _service;

  AppointmentsNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> fetchAppointments({String? userId, String? status}) async {
    try {
      state = const AsyncValue.loading();
      final appointments = await _service.listAppointments(userId: userId, status: status);
      if (mounted) {
        state = AsyncValue.data(appointments);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> createAppointment(Appointment appointment, {String? targetUserId, String? currentStatusFilter}) async {
    try {
      final newAppt = await _service.createAppointment(appointment);
      if (state.hasValue && state.value != null) {
        bool matchesStatus = currentStatusFilter == null || currentStatusFilter == 'all' || newAppt.status == currentStatusFilter;
        if (matchesStatus) {
          final newList = List<Appointment>.from(state.value!);
          // Keep it sorted by date (upcoming first if status is upcoming, otherwise descending)
          if (newAppt.status == 'upcoming') {
            newList.add(newAppt);
            newList.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
          } else {
            newList.insert(0, newAppt);
            newList.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
          }
          state = AsyncValue.data(newList);
        }
      } else {
        await fetchAppointments(userId: targetUserId, status: currentStatusFilter);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAppointment(Appointment appointment, {String? targetUserId, String? currentStatusFilter}) async {
    try {
      final updatedAppt = await _service.updateAppointment(appointment);
      if (state.hasValue && state.value != null) {
        final currentList = state.value!;
        final index = currentList.indexWhere((a) => a.id == appointment.id);
        
        bool matchesStatus = currentStatusFilter == null || currentStatusFilter == 'all' || updatedAppt.status == currentStatusFilter;

        if (index != -1) {
          final newList = List<Appointment>.from(currentList);
          if (matchesStatus) {
            newList[index] = updatedAppt;
            if (updatedAppt.status == 'upcoming') {
              newList.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
            } else {
              newList.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
            }
          } else {
            newList.removeAt(index);
          }
          state = AsyncValue.data(newList);
        } else {
          await fetchAppointments(userId: targetUserId, status: currentStatusFilter);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAppointment(String id, {String? targetUserId, String? currentStatusFilter}) async {
    try {
      await _service.deleteAppointment(id);
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(
          state.value!.where((a) => a.id != id).toList()
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAppointmentCompleted(String id, {String? targetUserId, String? currentStatusFilter}) async {
    try {
      final completedAppt = await _service.markAppointmentCompleted(id);
      if (state.hasValue && state.value != null) {
        final currentList = state.value!;
        final index = currentList.indexWhere((a) => a.id == id);
        
        bool matchesStatus = currentStatusFilter == null || currentStatusFilter == 'all' || completedAppt.status == currentStatusFilter;

        if (index != -1) {
          final newList = List<Appointment>.from(currentList);
          if (matchesStatus) {
            newList[index] = completedAppt;
            newList.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
          } else {
            newList.removeAt(index);
          }
          state = AsyncValue.data(newList);
        } else {
          await fetchAppointments(userId: targetUserId, status: currentStatusFilter);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<AppointmentNote?> getAppointmentNote(String appointmentId) {
    return _service.getAppointmentNote(appointmentId);
  }

  Future<AppointmentNote> upsertAppointmentNote(AppointmentNote note) {
    return _service.upsertAppointmentNote(note);
  }
}
