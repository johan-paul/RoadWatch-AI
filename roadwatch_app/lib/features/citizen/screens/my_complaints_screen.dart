import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/complaint_card.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../providers/citizen_provider.dart';

class MyComplaintsScreen extends ConsumerWidget {
  const MyComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(citizenComplaintsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(citizenComplaintsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () =>
            ref.read(citizenComplaintsProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, ComplaintsState state) {
    if (state.isLoading && state.complaints.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 6,
        itemBuilder: (_, __) => const LoadingCard(),
      );
    }

    if (state.error != null && state.complaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 36, color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(citizenComplaintsProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.complaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.citizen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_outlined,
                    size: 44, color: AppColors.citizen),
              ),
              const SizedBox(height: 20),
              const Text(
                'No reports yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Spotted a road hazard?\nReport it and help your community!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.go('/citizen/report'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: AppColors.reportGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.citizen.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Report Hazard',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
            state.hasMore &&
            !state.isLoading) {
          ref.read(citizenComplaintsProvider.notifier).load();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 110),
        itemCount: state.complaints.length + (state.hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == state.complaints.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }
          final c = state.complaints[i];
          return ComplaintCard(
            complaint: c,
            onTap: () => context.push('/citizen/complaints/${c.id}'),
          );
        },
      ),
    );
  }
}
