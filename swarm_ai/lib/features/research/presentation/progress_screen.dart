import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/agent_card.dart';
import '../data/research_api.dart';
import '../domain/research_model.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ResearchApi _researchApi = ResearchApi();
  Timer? _pollTimer;
  Timer? _connectionTimer;

  String _query = '';
  String _status = 'pending';
  int _progress = 0;
  String _phase = '';
  String? _message;
  String? _errorMessage;
  String? _error;
  BackendConnectionStatus? _connectionStatus;
  List<AgentProgress> _agents = const <AgentProgress>[];
  List<String> _logs = const <String>[];

  @override
  void initState() {
    super.initState();
    _checkBackendConnection();
    _connectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkBackendConnection(),
    );
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBackendConnection() async {
    final status = await _researchApi.checkConnectionStatus(logIfDebug: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _connectionStatus = status;
    });
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
    final specialists = _agentFor('Specialist Agents');
    final analyzer = _agentFor('Analyzer Agent');
    final resolver = _agentFor('Conflict Resolver');
    final synthesis = _agentFor('Synthesis Agent');
    final coherence = _agentFor('Coherence Scorer');

    return Scaffold(
      appBar: AppBar(title: const Text('Researching...')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionStatusBanner(status: _connectionStatus),
          const SizedBox(height: 10),
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
            agentName: 'Specialist Agents',
            emoji: '🔍',
            status: _agentRunStatus(specialists?.status) ?? statuses[1],
            message: specialists?.message ?? 'Running specialist searches in parallel',
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
            agentName: 'Conflict Resolver',
            emoji: '⚖️',
            status: _agentRunStatus(resolver?.status) ?? statuses[3],
            message: resolver?.message ?? 'Resolving conflicting evidence',
          ),
          const SizedBox(height: 12),
          AgentCard(
            agentName: 'Synthesis Agent',
            emoji: '🧩',
            status: _agentRunStatus(synthesis?.status) ?? statuses[4],
            message: synthesis?.message ?? 'Building the final report',
          ),
          const SizedBox(height: 12),
          AgentCard(
            agentName: 'Coherence Scorer',
            emoji: '✅',
            status: _agentRunStatus(coherence?.status) ?? statuses[5],
            message: coherence?.message ?? 'Scoring report coherence',
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
                border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _logs.reversed
                    .take(5)
                    .map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    )
                    .toList(growable: false),
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
    );
  }

  List<AgentRunStatus> _buildAgentStatuses(String status) {
    switch (status) {
      case 'pending':
      case 'orchestration':
        return const <AgentRunStatus>[
          AgentRunStatus.running,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
        ];
      case 'searching':
        return const <AgentRunStatus>[
          AgentRunStatus.done,
          AgentRunStatus.running,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
        ];
      case 'analyzing':
        return const <AgentRunStatus>[
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.running,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
        ];
      case 'resolving':
        return const <AgentRunStatus>[
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.running,
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
        ];
      case 'synthesis':
      case 'writing':
        return const <AgentRunStatus>[
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.running,
          AgentRunStatus.waiting,
        ];
      case 'coherence':
        return const <AgentRunStatus>[
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.running,
        ];
      case 'completed':
        return const <AgentRunStatus>[
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
        ];
      case 'failed':
        return const <AgentRunStatus>[
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.done,
          AgentRunStatus.waiting,
        ];
      default:
        return const <AgentRunStatus>[
          AgentRunStatus.waiting,
          AgentRunStatus.waiting,
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
          return 'Searching specialist sources...';
        case 'analyzing':
          return 'Analyzing findings...';
        case 'resolving':
          return 'Resolving source conflicts...';
        case 'synthesis':
        case 'writing':
          return 'Synthesizing final report...';
        case 'coherence':
          return 'Checking coherence and quality...';
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
        return 'Searching specialist sources...';
      case 'analyzing':
        return 'Analyzing findings...';
      case 'resolving':
        return 'Resolving source conflicts...';
      case 'synthesis':
      case 'writing':
        return 'Synthesizing final report...';
      case 'coherence':
        return 'Checking coherence and quality...';
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

class _ConnectionStatusBanner extends StatelessWidget {
  const _ConnectionStatusBanner({required this.status});

  final BackendConnectionStatus? status;

  @override
  Widget build(BuildContext context) {
    final isConnected = status?.isConnected ?? false;
    final color = isConnected ? AppColors.success : Colors.redAccent;
    final text = status == null
        ? 'Checking backend connection...'
        : isConnected
            ? 'Backend connected: ${status!.baseUrl}'
            : 'Backend disconnected: ${status!.message}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
