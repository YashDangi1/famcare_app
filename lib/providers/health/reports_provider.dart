import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/health/reports_service.dart';
import '../../models/health/health_report_request.dart';

final reportsServiceProvider = Provider((ref) => ReportsService());

class ReportsState {
  final bool isGenerating;
  final HealthReportPreview? preview;
  final String? error;

  ReportsState({this.isGenerating = false, this.preview, this.error});

  ReportsState copyWith({bool? isGenerating, HealthReportPreview? preview, String? error}) {
    return ReportsState(
      isGenerating: isGenerating ?? this.isGenerating,
      preview: preview ?? this.preview,
      error: error, // overwrite error with null if not provided
    );
  }
}

final reportsProvider = StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  final service = ref.watch(reportsServiceProvider);
  return ReportsNotifier(service);
});

class ReportsNotifier extends StateNotifier<ReportsState> {
  final ReportsService _service;

  ReportsNotifier(this._service) : super(ReportsState());

  Future<HealthReportPreview?> buildDoctorVisitReport(HealthReportRequest request) async {
    state = state.copyWith(isGenerating: true, error: null);
    try {
      final preview = await _service.buildDoctorVisitReport(request);
      state = state.copyWith(isGenerating: false, preview: preview);
      return preview;
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      return null;
    }
  }

  Future<HealthReportPreview?> buildVitalsSummaryReport(HealthReportRequest request) async {
    state = state.copyWith(isGenerating: true, error: null);
    try {
      final preview = await _service.buildVitalsSummaryReport(request);
      state = state.copyWith(isGenerating: false, preview: preview);
      return preview;
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      return null;
    }
  }

  Future<HealthReportPreview?> buildFullHealthSummaryReport(HealthReportRequest request) async {
    state = state.copyWith(isGenerating: true, error: null);
    try {
      final preview = await _service.buildFullHealthSummaryReport(request);
      state = state.copyWith(isGenerating: false, preview: preview);
      return preview;
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      return null;
    }
  }



  void clearPreview() {
    state = ReportsState();
  }
}
