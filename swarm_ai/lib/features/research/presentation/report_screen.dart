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
      final generatedAt = DateTime.now();
      final generatedAtText =
          '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} '
          '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(34, 38, 34, 42),
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.blue200, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Swarm AI Research Report',
                      style: pw.TextStyle(
                        fontSize: 23,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      report.query,
                      style: pw.TextStyle(
                        fontSize: 13,
                        color: PdfColors.blueGrey900,
                        lineSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _pdfMetaChip('Job ID: ${report.jobId}'),
                        _pdfMetaChip('Sections: ${report.sections.length}'),
                        _pdfMetaChip('Sources: ${report.totalSources}'),
                        _pdfMetaChip('Generated: $generatedAtText'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 22),

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
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  report.summary,
                  style: const pw.TextStyle(fontSize: 11.2, lineSpacing: 2),
                  textAlign: pw.TextAlign.justify,
                ),
              ),
              pw.SizedBox(height: 18),

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
              pw.SizedBox(height: 8),
              ...report.sections.asMap().entries.map((entry) {
                final sectionIndex = entry.key + 1;
                final section = entry.value;

                return pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 14),
                  padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '$sectionIndex. ${section.title}',
                        style: pw.TextStyle(
                          fontSize: 13.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 7),
                      pw.Text(
                        section.content,
                        style: const pw.TextStyle(fontSize: 10.8, lineSpacing: 1.9),
                        textAlign: pw.TextAlign.justify,
                      ),
                      if (section.sources.isNotEmpty) ...[
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'Sources',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        ...section.sources.map((source) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 2),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    '- ',
                                    style: pw.TextStyle(
                                      fontSize: 9.4,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text(
                                      source,
                                      style: pw.TextStyle(
                                        fontSize: 9.4,
                                        color: PdfColors.blue700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                );
              }),

              pw.Container(
                margin: const pw.EdgeInsets.only(top: 20),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        fontSize: 9.5,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.Text(
                      'Total Sources: ${report.totalSources}',
                      style: pw.TextStyle(
                        fontSize: 9.5,
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

  pw.Widget _pdfMetaChip(String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(999),
        border: pw.Border.all(color: PdfColors.blue100, width: 0.8),
      ),
      child: pw.Text(
        value,
        style: pw.TextStyle(fontSize: 9.4, color: PdfColors.blueGrey800),
      ),
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
              Text(
                report.query,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Text('Summary', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                report.summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaPill(context, Icons.view_agenda_rounded, '${report.sections.length} sections'),
                  _buildMetaPill(context, Icons.link_rounded, '${report.totalSources} sources'),
                ],
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

  Widget _buildMetaPill(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
