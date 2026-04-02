import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  Future<void> _downloadPdf() async {
    final report = _report;
    if (report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );

      final pdf = pw.Document();

      // Create PDF with proper page handling
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Title
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Swarm AI Research Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Query
              pw.Text(
                'Research Query:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                report.query,
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 20),

              // Summary Section
              pw.Header(
                level: 1,
                child: pw.Text(
                  'Executive Summary',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                report.summary,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 20),

              // Sections
              pw.Header(
                level: 1,
                child: pw.Text(
                  'Detailed Analysis',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
              pw.SizedBox(height: 15),

              // Generate sections
              ...report.sections.map((section) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 2,
                    child: pw.Text(
                      section.title,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    section.content,
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
                    textAlign: pw.TextAlign.justify,
                  ),
                  if (section.sources.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Sources:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    ...section.sources.map((source) => pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Text(
                        source,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.blue600,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                    )),
                  ],
                  pw.SizedBox(height: 15),
                ],
              )),

              // Footer with total sources
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 20),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Generated by Swarm AI',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.Text(
                      'Total Sources: ${report.totalSources}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Save PDF bytes
      final bytes = await pdf.save();

      if (bytes.isEmpty) {
        throw Exception('PDF generation resulted in empty bytes');
      }

      // Share the PDF
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'swarm_ai_report_${report.jobId}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF downloaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: ${e.toString()}')),
        );
      }
    }
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
          IconButton(
            onPressed: _report == null ? null : _downloadPdf,
            icon: const Icon(Icons.download_rounded),
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
