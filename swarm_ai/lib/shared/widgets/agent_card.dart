import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AgentRunStatus { waiting, running, done }

class AgentCard extends StatefulWidget {
  const AgentCard({
    super.key,
    required this.agentName,
    required this.emoji,
    required this.status,
    required this.message,
  });

  final String agentName;
  final String emoji;
  final AgentRunStatus status;
  final String message;

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AgentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.status == AgentRunStatus.running) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _leftBorderColor(widget.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Text(widget.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agentName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusIndicator(status: widget.status, animation: _controller),
        ],
      ),
    );
  }

  Color _leftBorderColor(AgentRunStatus status) {
    switch (status) {
      case AgentRunStatus.waiting:
        return AppColors.textSecondary;
      case AgentRunStatus.running:
        return AppColors.secondary;
      case AgentRunStatus.done:
        return AppColors.success;
    }
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status, required this.animation});

  final AgentRunStatus status;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case AgentRunStatus.waiting:
        return const Icon(Icons.schedule_rounded, color: AppColors.textSecondary);
      case AgentRunStatus.running:
        return FadeTransition(
          opacity: Tween<double>(begin: 0.3, end: 1).animate(animation),
          child: const Icon(Icons.sync_rounded, color: AppColors.secondary),
        );
      case AgentRunStatus.done:
        return const Icon(Icons.check_circle_rounded, color: AppColors.success);
    }
  }
}
