import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/research_api.dart';
import '../domain/research_model.dart';
import '../../../shared/widgets/agent_card.dart';
import '../../../core/theme/app_colors.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ResearchApi _researchApi = ResearchApi();
  Timer? _pollTimer;

  String _query = '';
  String _status = 'running';
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final ResearchJob job = await _researchApi.getJobStatus(widget.jobId);
      if (!mounted) {
        return;
      }

      setState(() {
        _query = job.query;
        _status = job.status;
        _error = null;
      });

      if (job.status == 'completed') {
        _pollTimer?.cancel();
        context.go('/report/${widget.jobId}');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to fetch status. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _buildAgentStatuses(_status);

    return Scaffold(
      appBar: AppBar(title: const Text('Researching...')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _query.isEmpty ? 'Preparing your job...' : _query,
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            AgentCard(
              agentName: 'Orchestrator',
              emoji: '🎯',
              status: statuses[0],
              message: 'Breaking down your query',
            ),
            const SizedBox(height: 12),
            AgentCard(
              agentName: 'Web Search Agent',
              emoji: '🔍',
              status: statuses[1],
              message: 'Searching the web',
            ),
            const SizedBox(height: 12),
            AgentCard(
              agentName: 'Analyzer Agent',
              emoji: '🧠',
              status: statuses[2],
              message: 'Analyzing results',
            ),
            const SizedBox(height: 12),
            AgentCard(
              agentName: 'Report Writer',
              emoji: '✍️',
              status: statuses[3],
              message: 'Writing your report',
            ),
            if (_error != null) ...[
              const SizedBox(height: 18),
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _poll,
                child: const Text('Retry'),
              ),
            ],
            if (_status == 'failed') ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                ),
                child: const Text(
                  'Research failed. Please retry from Home.',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<AgentRunStatus> _buildAgentStatuses(String status) {
    switch (status) {
      case 'running':
      case 'agent_1_running':
        return const [
          AgentRunStatus.running,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
        ];
      case 'agent_2_running':
        return const [
          AgentRunStatus.done,
          AgentRunStatus.running,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
        ];
      case 'agent_3_running':
        return const [
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.running,
          AgentRunStatus.waiting,
        ];
      case 'agent_4_running':
        return const [
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.running,
        ];
      case 'completed':
        return const [
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
        ];
      case 'failed':
        return const [
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.waiting,
        ];
      default:
        return const [
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
        ];
    }
  }
}
