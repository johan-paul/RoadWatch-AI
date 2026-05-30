import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/complaint_card.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../providers/officer_provider.dart';

class AssignedComplaintsScreen extends ConsumerStatefulWidget {
  const AssignedComplaintsScreen({super.key});

  @override
  ConsumerState<AssignedComplaintsScreen> createState() =>
      _AssignedComplaintsScreenState();
}

class _AssignedComplaintsScreenState
    extends ConsumerState<AssignedComplaintsScreen> {
  // Filter tabs: null = All
  static const _filters = <String?>[null, 'assigned', 'in_progress', 'resolved'];
  static const _labels  = ['All', 'Assigned', 'In Progress', 'Resolved'];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(officerComplaintsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Assignments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(officerComplaintsProvider.notifier).refresh(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _FilterTabs(
            selectedIndex: _selectedIndex,
            labels:        _labels,
            onChanged:     (i) {
              if (_selectedIndex == i) return;
              setState(() => _selectedIndex = i);
              ref
                  .read(officerComplaintsProvider.notifier)
                  .applyFilter(_filters[i]);
            },
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(officerComplaintsProvider.notifier).refresh(),
        child: state.isLoading && state.complaints.isEmpty
            ? ListView.builder(
                itemCount: 6,
                itemBuilder: (_, __) => const LoadingCard(),
              )
            : state.error != null && state.complaints.isEmpty
                ? _ErrorState(
                    error: state.error!,
                    onRetry: () =>
                        ref.read(officerComplaintsProvider.notifier).refresh(),
                  )
                : state.complaints.isEmpty
                    ? const _EmptyState()
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n is ScrollEndNotification &&
                              n.metrics.pixels >=
                                  n.metrics.maxScrollExtent - 200 &&
                              state.hasMore &&
                              !state.isLoading) {
                            ref.read(officerComplaintsProvider.notifier).load();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: state.complaints.length +
                              (state.hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == state.complaints.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            final c = state.complaints[i];
                            return ComplaintCard(
                              complaint: c,
                              onTap: () => context
                                  .push('/officer/complaints/${c.id}'),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}

// ── Filter tab row ────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });
  final int selectedIndex;
  final List<String> labels;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primary,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: List.generate(
              labels.length,
              (i) => GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? Colors.white
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selectedIndex == i
                          ? AppColors.primary
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.assignment_outlined, size: 64, color: AppColors.textHint),
            SizedBox(height: 16),
            Text('No complaints found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Pull down to refresh',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
