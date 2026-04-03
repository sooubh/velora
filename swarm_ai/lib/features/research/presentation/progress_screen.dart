import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

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
  String _status = 'pending';
  int _progress = 0;
  String _phase = '';
  String? _message;
  String? _errorMessage;
  String? _error;
  List<AgentProgress> _agents = const <AgentProgress>[];
  List<String> _logs = const <String>[];

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
        _progress = job.progress;
        _phase = job.phase;
        _message = job.message;
        _errorMessage = job.errorMessage;
        _agents = job.agents;
        _logs = job.logs;
        _error = null;
      });

      if (job.status == 'completed') {
        _pollTimer?.cancel();
        context.go('/report/${widget.jobId}');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'failed';
        _error = _formatPollError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _buildAgentStatuses(_status);
    final orchestrator = _agentFor('Orchestrator');
    final webSearch = _agentFor('Web Search Agent');
    final analyzer = _agentFor('Analyzer Agent');
    final writer = _agentFor('Report Writer');

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
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (_progress.clamp(0, 100)) / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(height: 8),
            Text(
              _message ?? _phaseLabel(_phase, _status),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Progress: $_progress%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AgentCard(
              agentName: 'Orchestrator',
              emoji: '🎯',
              status: _agentRunStatus(orchestrator?.status) ?? statuses[0],
              message: orchestrator?.message ?? 'Breaking down your query',
            ),
            const SizedBox(height: 12),
            AgentCard(
              agentName: 'Web Search Agent',
              emoji: '🔍',
              status: _agentRunStatus(webSearch?.status) ?? statuses[1],
              message: webSearch?.message ?? 'Searching the web',
            ),
            const SizedBox(height: 12),
            AgentCard(
              agentName: 'Analyzer Agent',
              emoji: '🧠',
              status: _agentRunStatus(analyzer?.status) ?? statuses[2],
              message: analyzer?.message ?? 'Analyzing results',
            ),
            const SizedBox(height: 12),
            AgentCard(
              agentName: 'Report Writer',
              emoji: '✍️',
              status: _agentRunStatus(writer?.status) ?? statuses[3],
              message: writer?.message ?? 'Writing your report',
            ),
            if (_logs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Live activity log',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _logs.reversed.take(5).map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )).toList(growable: false),
                ),
              ),
            ],
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
                child: Text(
                  _errorMessage?.isNotEmpty == true
                      ? 'Research failed: $_errorMessage'
                      : 'Research failed. Please retry from Home.',
                  style: const TextStyle(color: AppColors.textPrimary),
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
      case 'pending':
      case 'orchestration':
        return const [
          AgentRunStatus.running,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
        ];
      case 'searching':
        return const [
          AgentRunStatus.done,
          AgentRunStatus.running,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
        ];
      case 'analyzing':
        return const [
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.running,
          AgentRunStatus.waiting,
        ];
      case 'writing':
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

  String _phaseLabel(String phase, String status) {
    if (phase.isNotEmpty) {
      switch (phase) {
        case 'orchestration':
          return 'Planning research strategy...';
        case 'searching':
          return 'Searching the web...';
        case 'analyzing':
          return 'Analyzing findings...';
        case 'writing':
          return 'Writing final report...';
        case 'completed':
          return 'Research complete!';
      }
    }

    switch (status) {
      case 'pending':
        return 'Preparing your research...';
      case 'orchestration':
        return 'Planning research strategy...';
      case 'searching':
        return 'Searching the web...';
      case 'analyzing':
        return 'Analyzing findings...';
      case 'writing':
        return 'Writing final report...';
      case 'completed':
        return 'Research complete!';
      case 'failed':
        return 'Research failed.';
      default:
        return 'Working on your request...';
    }
  }

  String _formatPollError(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 404) {
        return 'Research session not found. It may have expired after backend restart. Please start again.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Unable to fetch status. Check backend connection.';
      }
      return 'Status request failed: ${error.message ?? 'unknown network error'}';
    }

    return 'Unable to fetch status. Please try again.';
  }

  AgentProgress? _agentFor(String name) {
    for (final agent in _agents) {
      if (agent.agentName == name) {
        return agent;
      }
    }
    return null;
  }

  AgentRunStatus? _agentRunStatus(String? rawStatus) {
    switch (rawStatus) {
      case 'running':
        return AgentRunStatus.running;
      case 'done':
        return AgentRunStatus.done;
      case 'waiting':
        return AgentRunStatus.waiting;
      default:
        return null;
    }
  }
}
