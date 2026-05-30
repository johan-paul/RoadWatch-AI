import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../data/citizen_repository.dart';
import '../models/complaint_model.dart';

final citizenRepositoryProvider = Provider<CitizenRepository>((ref) {
  return CitizenRepository(ref.watch(apiClientProvider));
});

// ── Complaints list ───────────────────────────────────────────────────────────

class ComplaintsState {
  const ComplaintsState({
    this.complaints = const [],
    this.isLoading  = false,
    this.error,
    this.hasMore    = true,
    this.page       = 1,
  });

  final List<ComplaintModel> complaints;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int page;

  ComplaintsState copyWith({
    List<ComplaintModel>? complaints,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? page,
    bool clearError = false,
  }) =>
      ComplaintsState(
        complaints: complaints ?? this.complaints,
        isLoading:  isLoading  ?? this.isLoading,
        error:      clearError ? null : (error ?? this.error),
        hasMore:    hasMore    ?? this.hasMore,
        page:       page       ?? this.page,
      );
}

class CitizenComplaintsNotifier extends StateNotifier<ComplaintsState> {
  CitizenComplaintsNotifier(this._repo) : super(const ComplaintsState()) {
    load();
  }

  final CitizenRepository _repo;

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading) return;
    final page = refresh ? 1 : state.page;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.getMyComplaints(page: page);
      state = state.copyWith(
        complaints: refresh ? items : [...state.complaints, ...items],
        isLoading:  false,
        hasMore:    items.length == 20,
        page:       page + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load(refresh: true);
}

final citizenComplaintsProvider =
    StateNotifierProvider<CitizenComplaintsNotifier, ComplaintsState>((ref) {
  return CitizenComplaintsNotifier(ref.watch(citizenRepositoryProvider));
});

// ── Single complaint ──────────────────────────────────────────────────────────

final complaintDetailProvider =
    FutureProvider.family<ComplaintModel, String>((ref, id) async {
  return ref.watch(citizenRepositoryProvider).getComplaint(id);
});

// ── Heatmap ───────────────────────────────────────────────────────────────────

final heatmapProvider = FutureProvider<List<HeatmapPoint>>((ref) async {
  return ref.watch(citizenRepositoryProvider).getHeatmap();
});
