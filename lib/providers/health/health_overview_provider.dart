import 'package:flutter_riverpod/flutter_riverpod.dart';

class HealthOverviewData {
  final Map<String, dynamic>? latestVital;
  final dynamic nextAppointment;
  final List<dynamic> recentSymptoms;
  final List<dynamic> recentRecords;
  final int activeMedsCount;
  final int lowStockCount;
  final bool hasCriticalIssue;

  HealthOverviewData({
    this.latestVital,
    this.nextAppointment,
    this.recentSymptoms = const [],
    this.recentRecords = const [],
    this.activeMedsCount = 0,
    this.lowStockCount = 0,
    this.hasCriticalIssue = false,
  });
}

class HealthOverviewNotifier extends StateNotifier<AsyncValue<HealthOverviewData>> {
  HealthOverviewNotifier() : super(const AsyncValue.loading());

  Future<void> fetchOverview(String userId) async {
    // Stub
    state = AsyncValue.data(HealthOverviewData());
  }
}

final healthOverviewProvider = StateNotifierProvider<HealthOverviewNotifier, AsyncValue<HealthOverviewData>>((ref) {
  return HealthOverviewNotifier();
});
