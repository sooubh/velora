import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isSubmitting = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start research.')),
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
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('research')
                          .where('userId', isEqualTo: uid)
                          .orderBy('createdAt', descending: true)
                          .limit(20)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return const Center(child: Text('Failed to load history'));
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(child: Text('No recent research yet.'));
                        }

                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = docs[index].data();
                            final jobId = docs[index].id;
                            final query = (item['query'] ?? 'Untitled query').toString();
                            final status = (item['status'] ?? 'running').toString();
                            final createdAt = item['createdAt'] is Timestamp
                                ? (item['createdAt'] as Timestamp).toDate()
                                : null;

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
                      },
                    ),
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
