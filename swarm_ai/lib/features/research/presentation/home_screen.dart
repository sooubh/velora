import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';

import '../../auth/data/firebase_auth_service.dart';
import '../data/research_api.dart';
import '../../../../core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ResearchApi _researchApi = ResearchApi();
  final TextEditingController _queryController = TextEditingController();
  Timer? _connectionTimer;
  bool _isSubmitting = false;
  BackendConnectionStatus? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _checkBackendConnection();
    _connectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkBackendConnection(),
    );
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _queryController.dispose();
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

  Future<void> _startResearch() async {
    final query = _queryController.text.trim();
    final user = _authService.getCurrentUser();

    if (query.isEmpty || user == null || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final jobId = await _researchApi.startResearch(query: query, userId: user.uid);
      if (!mounted) {
        return;
      }
      context.push('/progress/$jobId');
      _queryController.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatStartError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  String _formatStartError(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;

      if (responseData is Map<String, dynamic>) {
        final detail = responseData['detail']?.toString();
        if (detail != null && detail.isNotEmpty) {
          return 'Failed to start research: $detail';
        }
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'Failed to start research: cannot reach backend. Ensure API is running on port 8000.';
      }

      return 'Failed to start research: ${error.message ?? 'request error'}';
    }

    return 'Failed to start research: ${error.toString()}';
  }

  Widget _buildDemoResearchList() {
    final demoItems = [
      {
        'jobId': 'demo1',
        'query': 'Latest advancements in quantum computing',
        'status': 'completed',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
      },
      {
        'jobId': 'demo2',
        'query': 'Impact of AI on healthcare industry',
        'status': 'completed',
        'createdAt': DateTime.now().subtract(const Duration(hours: 5)),
      },
      {
        'jobId': 'demo3',
        'query': 'Sustainable energy solutions for 2030',
        'status': 'running',
        'createdAt': DateTime.now().subtract(const Duration(hours: 1)),
      },
      {
        'jobId': 'demo4',
        'query': 'Blockchain technology applications beyond cryptocurrency',
        'status': 'completed',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      },
      {
        'jobId': 'demo5',
        'query': 'Climate change mitigation strategies',
        'status': 'failed',
        'createdAt': DateTime.now().subtract(const Duration(days: 2)),
      },
      {
        'jobId': 'demo6',
        'query': 'Future of remote work and digital nomadism',
        'status': 'completed',
        'createdAt': DateTime.now().subtract(const Duration(days: 3)),
      },
      {
        'jobId': 'demo7',
        'query': 'Advancements in renewable energy storage',
        'status': 'running',
        'createdAt': DateTime.now().subtract(const Duration(hours: 3)),
      },
      {
        'jobId': 'demo8',
        'query': 'The role of AI in education',
        'status': 'completed',
        'createdAt': DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      },
    ];

    return ListView.separated(
      itemCount: demoItems.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = demoItems[index];
        final jobId = item['jobId'] as String;
        final query = item['query'] as String;
        final status = item['status'] as String;
        final createdAt = item['createdAt'] as DateTime;

        return Card(
          child: ListTile(
            title: Text(
              query,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_formatDate(createdAt)),
            trailing: _StatusChip(status: status),
            onTap: () {
              final target = status == 'completed'
                  ? '/report/$jobId'
                  : '/progress/$jobId';
              context.push(target);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Swarm AI'),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: AppColors.surface,
              child: Text(
                (user?.displayName?.trim().isNotEmpty ?? false)
                    ? user!.displayName![0].toUpperCase()
                    : 'U',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConnectionStatusBanner(status: _connectionStatus),
            const SizedBox(height: 10),
            Text(
              'What do you want to research?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _queryController,
              maxLines: 5,
              minLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Type your research query...',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _startResearch,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start Research'),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Recent Research',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: uid == null
                  ? const Center(child: Text('Sign in to see history'))
                  : _buildDemoResearchList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) {
      return 'Unknown date';
    }

    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

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
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
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
