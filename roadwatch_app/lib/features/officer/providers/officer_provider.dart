import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../citizen/models/complaint_model.dart';
import '../data/officer_repository.dart';
import '../models/officer_models.dart';

final officerRepositoryProvider = Provider<OfficerRepository>((ref) {
  return OfficerRepository(ref.watch(apiClientProvider));
});

// ── Assigned complaints list ──────────────────────────────────────────────────

class OfficerComplaintsState {
  const OfficerComplaintsState({
    this.complaints = const [],
    this.isLoading  = false,
    this.error,
    this.hasMore    = true,
    this.page       = 1,
    this.statusFilter,
  });

  final List<ComplaintModel> complaints;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int page;
  final String? statusFilter;

  OfficerComplaintsState copyWith({
    List<ComplaintModel>? complaints,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? page,
    String? statusFilter,
    bool clearError = false,
    bool clearFilter = false,
  }) =>
      OfficerComplaintsState(
        complaints:   complaints   ?? this.complaints,
        isLoading:    isLoading    ?? this.isLoading,
        error:        clearError   ? null : (error ?? this.error),
        hasMore:      hasMore      ?? this.hasMore,
        page:         page         ?? this.page,
        statusFilter: clearFilter  ? null : (statusFilter ?? this.statusFilter),
      );
}

class OfficerComplaintsNotifier extends StateNotifier<OfficerComplaintsState> {
  OfficerComplaintsNotifier(this._repo) : super(const OfficerComplaintsState()) {
    load();
  }

  final OfficerRepository _repo;

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading) return;
    final page = refresh ? 1 : state.page;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.getAssignedComplaints(
        page: page,
        status: state.statusFilter,
      );
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

  Future<void> applyFilter(String? status) async {
    state = state.copyWith(
      statusFilter: status,
      complaints:   [],
      hasMore:      true,
      page:         1,
      clearFilter:  status == null,
    );
    await load();
  }
}

final officerComplaintsProvider =
    StateNotifierProvider<OfficerComplaintsNotifier, OfficerComplaintsState>((ref) {
  return OfficerComplaintsNotifier(ref.watch(officerRepositoryProvider));
});

// ── Single complaint ──────────────────────────────────────────────────────────

final officerComplaintDetailProvider =
    FutureProvider.family<ComplaintModel, String>((ref, id) async {
  return ref.watch(officerRepositoryProvider).getComplaint(id);
});

// ── Officer stats ─────────────────────────────────────────────────────────────

final officerStatsProvider = FutureProvider<OfficerStats>((ref) async {
  return ref.watch(officerRepositoryProvider).getStats();
});

// ── Officer heatmap ───────────────────────────────────────────────────────────

final officerHeatmapProvider = FutureProvider<List<HeatmapPoint>>((ref) async {
  return ref.watch(officerRepositoryProvider).getHeatmap();
});
