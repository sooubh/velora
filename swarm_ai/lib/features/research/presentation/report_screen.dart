import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/research_api.dart';
import '../domain/research_model.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/report_section_card.dart';
import '../../../core/theme/app_colors.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ResearchApi _researchApi = ResearchApi();

  FinalReport? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final report = await _researchApi.getReport(widget.jobId);
      if (!mounted) {
        return;
      }

      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = 'Failed to load report. Please retry.';
      });
    }
  }

  Future<void> _onSourceTap(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Source URL copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Research Report'),
        actions: [
          IconButton(
            onPressed: _report == null
                ? null
                : () {
                    final allText = [
                      _report!.summary,
                      for (final section in _report!.sections) section.content,
                    ].join('\n\n');
                    Clipboard.setData(ClipboardData(text: allText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report copied to clipboard.')),
                    );
                  },
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingShimmer(itemCount: 4),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _loadReport,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final report = _report;
    if (report == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF5B21B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                report.summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Key Sections', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final section in report.sections) ...[
          ReportSectionCard(
            title: section.title,
            content: section.content,
            sources: section.sources,
            onSourceTap: _onSourceTap,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Text(
          'Total sources: ${report.totalSources}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
