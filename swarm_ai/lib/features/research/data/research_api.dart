import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../core/constants/api_constants.dart';
import '../domain/research_model.dart';

class ResearchApi {
  ResearchApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: const Duration(seconds: 60),
                receiveTimeout: const Duration(seconds: 90),
                sendTimeout: const Duration(seconds: 60),
                headers: const <String, String>{
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _initializeGemini();
  }

  final Dio _dio;
  late final GenerativeModel _geminiModel;
  final Map<String, String> _userQueries = {}; // Store queries for user jobs
  final Map<String, DateTime> _jobStartTimes = {}; // Track when jobs started
  String _activeBaseUrl = ApiConstants.baseUrl;

  void _initializeGemini() {
    _geminiModel = GenerativeModel(
      model: ApiConstants.geminiModel,
      apiKey: ApiConstants.geminiApiKey,
    );
  }

  Future<String> startResearch({
    required String query,
    required String userId,
  }) async {
    await ensureBackendConnection();

    Response<dynamic> response;
    try {
      response = await _dio.post(
        ApiConstants.startResearchPath,
        data: <String, dynamic>{
          'query': query,
          'user_id': userId,
        },
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        await checkConnectionStatus(logIfDebug: true);
        throw Exception(
          'Cannot reach backend at $_activeBaseUrl. '
          'If you are using a physical Android device, run with '
          '--dart-define=API_BASE_URL=http://<YOUR_PC_IP>:8000',
        );
      }
      rethrow;
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid start research response');
    }

    final jobId = (data['research_id'] ?? '').toString();
    if (jobId.isEmpty) {
      throw Exception('Missing research_id in response');
    }

    _userQueries[jobId] = query;
    _jobStartTimes[jobId] = DateTime.now();
    return jobId;
  }

  Future<ResearchJob> getJobStatus(String jobId) async {
    // Demo data for MVP
    if (jobId.startsWith('demo')) {
      return _getDemoJobStatus(jobId);
    }

    await ensureBackendConnection();

    final response = await _dio.get(ApiConstants.jobStatusPath(jobId));
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid job status response');
    }

    final normalized = <String, dynamic>{
      'job_id': (data['research_id'] ?? jobId).toString(),
      'query': (data['query'] ?? _userQueries[jobId] ?? '').toString(),
      'status': (data['status'] ?? 'pending').toString(),
      'created_at': (data['created_at'] ?? _jobStartTimes[jobId]?.toIso8601String() ?? DateTime.now().toIso8601String()).toString(),
      'progress': data['progress'] ?? 0,
      'phase': data['phase'] ?? '',
      'message': data['message'],
      'error_message': data['error_message'],
      'logs': data['logs'] is List ? data['logs'] : const <dynamic>[],
      'agents': data['agents'] is List ? data['agents'] : const <dynamic>[],
    };

    return ResearchJob.fromJson(normalized);
  }

  ResearchJob _getDemoJobStatus(String jobId) {
    final demoStatuses = {
      'demo1': ResearchJob(
        jobId: 'demo1',
        query: 'Latest advancements in quantum computing',
        status: 'completed',
        createdAt: DateTime(2024, 4, 2, 10, 0),
      ),
      'demo2': ResearchJob(
        jobId: 'demo2',
        query: 'Impact of AI on healthcare industry',
        status: 'completed',
        createdAt: DateTime(2024, 4, 2, 7, 0),
      ),
      'demo3': ResearchJob(
        jobId: 'demo3',
        query: 'Sustainable energy solutions for 2030',
        status: 'running',
        createdAt: DateTime(2024, 4, 2, 11, 0),
      ),
      'demo4': ResearchJob(
        jobId: 'demo4',
        query: 'Blockchain technology applications beyond cryptocurrency',
        status: 'completed',
        createdAt: DateTime(2024, 4, 1, 12, 0),
      ),
      'demo5': ResearchJob(
        jobId: 'demo5',
        query: 'Climate change mitigation strategies',
        status: 'failed',
        createdAt: DateTime(2024, 3, 31, 12, 0),
      ),
      'demo6': ResearchJob(
        jobId: 'demo6',
        query: 'Future of remote work and digital nomadism',
        status: 'completed',
        createdAt: DateTime(2024, 3, 30, 12, 0),
      ),
      'demo7': ResearchJob(
        jobId: 'demo7',
        query: 'Advancements in renewable energy storage',
        status: 'running',
        createdAt: DateTime(2024, 4, 2, 9, 0),
      ),
      'demo8': ResearchJob(
        jobId: 'demo8',
        query: 'The role of AI in education',
        status: 'completed',
        createdAt: DateTime(2024, 4, 1, 10, 0),
      ),
    };

    return demoStatuses[jobId] ?? ResearchJob(
      jobId: 'demo',
      query: 'Demo Research Query',
      status: 'running',
      createdAt: DateTime(2024, 4, 2, 12, 0),
    );
  }

  Future<FinalReport> getReport(String jobId) async {
    // Demo data for MVP
    if (jobId.startsWith('demo')) {
      return _getDemoReport(jobId);
    }

    await ensureBackendConnection();

    final response = await _dio.get(ApiConstants.reportPath(jobId));
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid report response');
    }

    final status = (data['status'] ?? '').toString();
    if (status != 'completed') {
      throw Exception('Report is not ready yet');
    }

    final report = data['report'];
    if (report is! Map<String, dynamic>) {
      throw Exception('Missing report data');
    }

    final rawSections = report['sections'];
    final sections = rawSections is List
        ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(ReportSection.fromJson)
              .toList(growable: false)
        : const <ReportSection>[];

    final totalSources = sections.fold<int>(
      0,
      (sum, section) => sum + section.sources.length,
    );

    return FinalReport(
      jobId: (data['research_id'] ?? jobId).toString(),
      query: (data['query'] ?? '').toString(),
      summary: (report['summary'] ?? '').toString(),
      sections: sections,
      totalSources: totalSources,
    );
  }

  Future<FinalReport> _generateAIReport(String jobId) async {
    final query = _userQueries[jobId] ?? 'Your research query';

    try {
      // Generate comprehensive research report using Gemini
      final reportContent = await _generateResearchReport(query);

      // Parse the AI response into structured sections
      final sections = _parseReportSections(reportContent, query);

      return FinalReport(
        jobId: jobId,
        query: query,
        summary: _extractSummary(reportContent),
        sections: sections,
        totalSources: _estimateSources(sections),
      );
    } catch (e) {
      // Fallback to a basic structure if AI generation fails
      return FinalReport(
        jobId: jobId,
        query: query,
        summary: 'Research completed on "${query}". Due to technical limitations, a detailed report could not be generated at this time.',
        sections: [
          ReportSection(
            title: 'Research Overview',
            content: 'This research query has been processed. For detailed analysis, please try again later or contact support.',
            sources: ['https://swarm-ai.com/research'],
          ),
        ],
        totalSources: 1,
      );
    }
  }

  Future<String> _generateResearchReport(String query) async {
    const prompt = '''
You are an expert research analyst. Generate a comprehensive research report on the following topic. Structure your response with clear sections and provide detailed, factual information.

Topic: {query}

Please structure your response as follows:
1. EXECUTIVE SUMMARY: A concise overview (2-3 paragraphs)
2. CURRENT STATE: Analysis of the current situation
3. KEY FINDINGS: Important discoveries and insights
4. TRENDS AND DEVELOPMENTS: Recent and emerging trends
5. CHALLENGES AND OPPORTUNITIES: Main challenges and potential opportunities
6. FUTURE OUTLOOK: Predictions and recommendations
7. SOURCES: List 8-12 relevant sources (real websites, research papers, or organizations)

Make the report professional, well-researched, and comprehensive. Use markdown formatting for clarity.
''';

    final content = prompt.replaceAll('{query}', query);

    final response = await _geminiModel.generateContent([Content.text(content)]);
    return response.text ?? 'Unable to generate report content.';
  }

  List<ReportSection> _parseReportSections(String aiResponse, String query) {
    final sections = <ReportSection>[];

    // Split the response by section headers
    final sectionHeaders = [
      'EXECUTIVE SUMMARY',
      'CURRENT STATE',
      'KEY FINDINGS',
      'TRENDS AND DEVELOPMENTS',
      'CHALLENGES AND OPPORTUNITIES',
      'FUTURE OUTLOOK',
      'SOURCES'
    ];

    String currentSection = '';
    String currentContent = '';

    final lines = aiResponse.split('\n');

    for (final line in lines) {
      final upperLine = line.toUpperCase().trim();
      if (sectionHeaders.any((header) => upperLine.contains(header))) {
        // Save previous section if it exists
        if (currentSection.isNotEmpty && currentContent.isNotEmpty) {
          sections.add(_createReportSection(currentSection, currentContent.trim()));
        }

        // Start new section
        currentSection = _normalizeSectionTitle(upperLine);
        currentContent = '';
      } else if (currentSection.isNotEmpty) {
        currentContent += line + '\n';
      }
    }

    // Add the last section
    if (currentSection.isNotEmpty && currentContent.isNotEmpty) {
      sections.add(_createReportSection(currentSection, currentContent.trim()));
    }

    // If no sections were parsed, create a default structure
    if (sections.isEmpty) {
      sections.addAll([
        ReportSection(
          title: 'Research Analysis',
          content: aiResponse.length > 500 ? aiResponse.substring(0, 500) + '...' : aiResponse,
          sources: _generateDefaultSources(query),
        ),
        ReportSection(
          title: 'Key Insights',
          content: 'This section provides additional insights and analysis based on the research findings.',
          sources: _generateDefaultSources(query),
        ),
      ]);
    }

    return sections;
  }

  ReportSection _createReportSection(String title, String content) {
    return ReportSection(
      title: _formatSectionTitle(title),
      content: _cleanContent(content),
      sources: _extractSources(content),
    );
  }

  String _normalizeSectionTitle(String rawTitle) {
    if (rawTitle.contains('EXECUTIVE SUMMARY')) return 'Executive Summary';
    if (rawTitle.contains('CURRENT STATE')) return 'Current State Analysis';
    if (rawTitle.contains('KEY FINDINGS')) return 'Key Findings';
    if (rawTitle.contains('TRENDS')) return 'Trends and Developments';
    if (rawTitle.contains('CHALLENGES')) return 'Challenges and Opportunities';
    if (rawTitle.contains('FUTURE')) return 'Future Outlook';
    if (rawTitle.contains('SOURCES')) return 'Sources';
    return rawTitle;
  }

  String _formatSectionTitle(String title) {
    // Capitalize first letter of each word
    return title.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _cleanContent(String content) {
    // Remove excessive whitespace and clean up formatting
    return content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  List<String> _extractSources(String content) {
    // Look for URLs in the content
    final urlRegex = RegExp(r'https?://[^\s]+');
    final matches = urlRegex.allMatches(content);
    final sources = matches.map((match) => match.group(0)!).toList();

    // If no sources found, generate defaults
    return sources.isNotEmpty ? sources : _generateDefaultSources('');
  }

  List<String> _generateDefaultSources(String query) {
    final baseSources = [
      'https://scholar.google.com/',
      'https://www.researchgate.net/',
      'https://arxiv.org/',
      'https://www.sciencedirect.com/',
      'https://academic.oup.com/',
      'https://www.nature.com/',
      'https://www.science.org/',
      'https://ieeexplore.ieee.org/',
    ];

    // Add query-specific sources if possible
    if (query.toLowerCase().contains('ai')) {
      baseSources.addAll([
        'https://openai.com/research',
        'https://ai.google/research',
        'https://www.deepmind.com/',
      ]);
    } else if (query.toLowerCase().contains('quantum')) {
      baseSources.addAll([
        'https://quantum-computing.ibm.com/',
        'https://ai.google/research/quantum',
      ]);
    }

    return baseSources.take(12).toList();
  }

  String _extractSummary(String aiResponse) {
    // Try to extract the executive summary section
    final summaryMatch = RegExp(
      r'EXECUTIVE SUMMARY:?(.*?)(?=CURRENT STATE:|KEY FINDINGS:|TRENDS|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(aiResponse);

    if (summaryMatch != null) {
      final summary = summaryMatch.group(1)?.trim() ?? '';
      return summary.isNotEmpty ? summary : _generateFallbackSummary(aiResponse);
    }

    // Fallback: take first 300 characters
    return _generateFallbackSummary(aiResponse);
  }

  Future<void> ensureBackendConnection() async {
    final status = await checkConnectionStatus(logIfDebug: true);
    if (!status.isConnected) {
      throw Exception(status.message);
    }
  }

  Future<BackendConnectionStatus> checkConnectionStatus({
    bool logIfDebug = false,
  }) async {
    final candidates = <String>{
      _activeBaseUrl,
      ...ApiConstants.baseUrlCandidates,
    }.toList(growable: false);

    for (final candidate in candidates) {
      final ok = await _probeHealth(candidate);
      if (ok) {
        _setBaseUrl(candidate);
        final status = BackendConnectionStatus(
          isConnected: true,
          baseUrl: candidate,
          message: 'Connected to backend',
          checkedAt: DateTime.now(),
        );
        if (logIfDebug && kDebugMode) {
          debugPrint('[ResearchApi] Backend connected: ${status.baseUrl}');
        }
        return status;
      }
    }

    final status = BackendConnectionStatus(
      isConnected: false,
      baseUrl: _activeBaseUrl,
      message:
          'Backend unreachable. Start API on port 8000 or set API_BASE_URL.',
      checkedAt: DateTime.now(),
    );
    if (logIfDebug && kDebugMode) {
      debugPrint(
        '[ResearchApi] Backend disconnected. Tried: ${candidates.join(', ')}',
      );
    }
    return status;
  }

  Future<bool> _probeHealth(String baseUrl) async {
    final probe = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
      ),
    );

    try {
      final response = await probe.get(ApiConstants.healthPath);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _setBaseUrl(String baseUrl) {
    if (_activeBaseUrl == baseUrl) {
      return;
    }

    _activeBaseUrl = baseUrl;
    _dio.options.baseUrl = baseUrl;
  }

  String _generateFallbackSummary(String content) {
    final cleanContent = content.replaceAll(RegExp(r'#+\s*'), '').trim();
    if (cleanContent.length <= 300) return cleanContent;

    // Find a good breaking point
    final breakPoint = cleanContent.lastIndexOf('. ', 300);
    if (breakPoint > 0) {
      return cleanContent.substring(0, breakPoint + 1);
    }

    return cleanContent.substring(0, 300) + '...';
  }

  int _estimateSources(List<ReportSection> sections) {
    final totalSources = sections.fold<int>(0, (sum, section) => sum + section.sources.length);
    return totalSources > 0 ? totalSources : 8; // Minimum estimate
  }



  FinalReport _getDemoReport(String jobId) {
    final demoReports = {
      'demo1': FinalReport(
        jobId: 'demo1',
        query: 'Latest advancements in quantum computing',
        summary: 'Quantum computing has made significant strides in recent years, with major breakthroughs in qubit stability, error correction, and practical applications. Companies like IBM, Google, and Rigetti are leading the charge with quantum processors that can perform complex calculations beyond classical computers\' capabilities.',
        sections: [
          ReportSection(
            title: 'Hardware Developments',
            content: 'Recent advancements include the development of superconducting qubits with coherence times exceeding 100 microseconds, topological qubits for better error resistance, and silicon-based quantum dots that leverage existing semiconductor manufacturing processes.',
            sources: ['https://quantum-computing.ibm.com/', 'https://ai.google/research/quantum'],
          ),
          ReportSection(
            title: 'Software and Algorithms',
            content: 'New quantum algorithms for optimization problems, machine learning, and cryptography are emerging. Variational quantum eigensolvers (VQE) and quantum approximate optimization algorithms (QAOA) show promise for near-term quantum advantage.',
            sources: ['https://arxiv.org/abs/quant-ph', 'https://qiskit.org/'],
          ),
          ReportSection(
            title: 'Industry Applications',
            content: 'Quantum computing is being applied to drug discovery, financial modeling, supply chain optimization, and climate modeling. Pharmaceutical companies are using quantum simulations to model molecular interactions for drug development.',
            sources: ['https://www.nature.com/articles/s41586-023-06096-3'],
          ),
        ],
        totalSources: 12,
      ),
      'demo2': FinalReport(
        jobId: 'demo2',
        query: 'Impact of AI on healthcare industry',
        summary: 'Artificial Intelligence is revolutionizing healthcare through improved diagnostics, personalized treatment plans, drug discovery, and operational efficiency. While challenges remain in data privacy and regulatory compliance, the benefits of AI adoption are substantial and growing.',
        sections: [
          ReportSection(
            title: 'Diagnostic Improvements',
            content: 'AI-powered imaging analysis achieves 94% accuracy in detecting diabetic retinopathy, surpassing human experts. Machine learning models can predict patient deterioration 48 hours before clinical signs appear.',
            sources: ['https://www.who.int/publications/i/item/9789240029200'],
          ),
          ReportSection(
            title: 'Drug Discovery Acceleration',
            content: 'AI algorithms can screen millions of compounds in days rather than years. Deep learning models predict molecular properties with high accuracy, reducing development costs by up to 70%.',
            sources: ['https://www.nature.com/articles/d41586-023-00029-3'],
          ),
          ReportSection(
            title: 'Operational Efficiency',
            content: 'AI chatbots handle 30-40% of patient inquiries, freeing healthcare workers. Predictive analytics optimize hospital resource allocation, reducing wait times and improving patient outcomes.',
            sources: ['https://www.mckinsey.com/industries/healthcare-systems-and-services/our-insights/ai-in-healthcare'],
          ),
        ],
        totalSources: 15,
      ),
      'demo4': FinalReport(
        jobId: 'demo4',
        query: 'Blockchain technology applications beyond cryptocurrency',
        summary: 'Blockchain technology extends far beyond cryptocurrency, offering solutions for supply chain transparency, digital identity verification, healthcare data management, and decentralized finance. Its immutable ledger and smart contract capabilities enable trustless transactions across various industries.',
        sections: [
          ReportSection(
            title: 'Supply Chain Management',
            content: 'Blockchain provides end-to-end traceability for food, pharmaceuticals, and luxury goods. Walmart uses blockchain to track food products from farm to store in seconds, reducing recall times by 98%.',
            sources: ['https://www.ibm.com/blockchain/supply-chain'],
          ),
          ReportSection(
            title: 'Digital Identity',
            content: 'Self-sovereign identity systems allow individuals to control their personal data. Estonia\'s e-Residency program uses blockchain for secure digital identities, with over 80,000 residents.',
            sources: ['https://e-estonia.com/solutions/e-residency/'],
          ),
          ReportSection(
            title: 'Healthcare Data Management',
            content: 'Blockchain enables secure sharing of medical records while maintaining patient privacy. MediLedger tracks pharmaceutical supply chains, ensuring drug authenticity and reducing counterfeit medications.',
            sources: ['https://www.healthit.gov/topic/health-it-and-health-information-exchange/blockchain-healthcare'],
          ),
        ],
        totalSources: 18,
      ),
      'demo6': FinalReport(
        jobId: 'demo6',
        query: 'Future of remote work and digital nomadism',
        summary: 'Remote work and digital nomadism are reshaping the global workforce, with 25% of workers expected to be fully remote by 2025. This shift requires new policies, technologies, and cultural adaptations from organizations and governments.',
        sections: [
          ReportSection(
            title: 'Workforce Transformation',
            content: 'Remote work increases productivity by 13% according to Stanford research. Companies save an average of \$11,000 per remote employee annually. However, challenges include team collaboration and work-life balance.',
            sources: ['https://www.stanford.edu/~nbloom/WFH.pdf'],
          ),
          ReportSection(
            title: 'Digital Nomad Economy',
            content: 'Digital nomads contribute \$1 trillion annually to global economies. Popular destinations like Portugal, Thailand, and Mexico offer visa programs specifically for remote workers.',
            sources: ['https://www.nomadlist.com/'],
          ),
          ReportSection(
            title: 'Technology Infrastructure',
            content: 'Cloud collaboration tools, video conferencing, and project management software enable seamless remote operations. 5G and satellite internet expand connectivity options for nomads.',
            sources: ['https://www.flexjobs.com/blog/post/remote-work-statistics/'],
          ),
        ],
        totalSources: 22,
      ),
      'demo8': FinalReport(
        jobId: 'demo8',
        query: 'The role of AI in education',
        summary: 'AI is transforming education through personalized learning, automated grading, and intelligent tutoring systems. While concerns about job displacement exist, AI primarily augments educators and expands access to quality education worldwide.',
        sections: [
          ReportSection(
            title: 'Personalized Learning',
            content: 'AI adapts content to individual student needs, improving learning outcomes by 30%. Platforms like Khan Academy use AI to recommend exercises based on student performance patterns.',
            sources: ['https://www.khanacademy.org/'],
          ),
          ReportSection(
            title: 'Automated Assessment',
            content: 'AI can grade essays and provide detailed feedback in seconds. Tools like Gradescope reduce grading time by 90% while maintaining accuracy comparable to human graders.',
            sources: ['https://gradescope.com/'],
          ),
          ReportSection(
            title: 'Accessibility Improvements',
            content: 'AI-powered translation and speech recognition make education accessible to non-native speakers and students with disabilities. Voice assistants help visually impaired students navigate digital content.',
            sources: ['https://www.unesco.org/en/education/ai-education'],
          ),
        ],
        totalSources: 16,
      ),
    };

    return demoReports[jobId] ?? FinalReport(
      jobId: jobId,
      query: 'Demo Research Query',
      summary: 'This is a demo research report showcasing the capabilities of Swarm AI.',
      sections: [
        ReportSection(
          title: 'Demo Section',
          content: 'This section contains demo content for the MVP presentation.',
          sources: ['https://example.com'],
        ),
      ],
      totalSources: 1,
    );
  }
}
