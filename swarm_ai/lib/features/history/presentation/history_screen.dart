import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import 'history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(researchHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Research History'),
      ),
      body: historyAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyHistory();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = _HistoryEntry.fromMap(items[index]);
              return _HistoryCard(entry: entry);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
                const SizedBox(height: 10),
                const Text('Failed to load saved research history.'),
                const SizedBox(height: 6),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.jobId,
    required this.query,
    required this.status,
    required this.createdAt,
    required this.summary,
    required this.sectionCount,
    required this.sourceCount,
  });

  final String jobId;
  final String query;
  final String status;
  final DateTime? createdAt;
  final String summary;
  final int sectionCount;
  final int sourceCount;

  factory _HistoryEntry.fromMap(Map<String, dynamic> data) {
    final report = data['report'] is Map<String, dynamic>
        ? data['report'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final sections = report['sections'] is List
        ? (report['sections'] as List)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final sourceCount = sections.fold<int>(
      0,
      (sum, section) => sum + ((section['sources'] as List?)?.length ?? 0),
    );

    final rawCreatedAt = data['created_at']?.toString() ?? data['createdAt']?.toString() ?? '';

    return _HistoryEntry(
      jobId: data['job_id']?.toString() ?? '',
      query: data['query']?.toString() ?? 'Untitled research',
      status: data['status']?.toString() ?? 'completed',
      createdAt: DateTime.tryParse(rawCreatedAt),
      summary: report['summary']?.toString() ?? '',
      sectionCount: sections.length,
      sourceCount: sourceCount,
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final target = entry.status.toLowerCase() == 'completed'
        ? '/report/${entry.jobId}'
        : '/progress/${entry.jobId}';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push(target),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.query,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(status: entry.status),
              ],
            ),
            const SizedBox(height: 10),
            if (entry.summary.trim().isNotEmpty)
              Text(
                entry.summary.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
              )
            else
              Text(
                'No summary available for this research report.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.schedule_rounded, label: _formatDate(entry.createdAt)),
                _InfoChip(icon: Icons.view_agenda_rounded, label: '${entry.sectionCount} sections'),
                _InfoChip(icon: Icons.link_rounded, label: '${entry.sourceCount} sources'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Unknown date';
    }

    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized == 'completed'
        ? AppColors.success
        : normalized == 'failed'
            ? Colors.redAccent
            : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.history_rounded, size: 34),
            ),
            const SizedBox(height: 12),
            Text('No research saved yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Start a research task and your reports will appear here in a clean timeline.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
