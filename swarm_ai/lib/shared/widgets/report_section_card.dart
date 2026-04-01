import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme/app_colors.dart';

class ReportSectionCard extends StatelessWidget {
  const ReportSectionCard({
    super.key,
    required this.title,
    required this.content,
    required this.sources,
    this.onSourceTap,
  });

  final String title;
  final String content;
  final List<String> sources;
  final ValueChanged<String>? onSourceTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          MarkdownBody(
            data: content,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Sources', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final source in sources)
              InkWell(
                onTap: () => onSourceTap?.call(source),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    source,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
