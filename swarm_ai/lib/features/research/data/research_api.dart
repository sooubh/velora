import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../domain/research_model.dart';

class ResearchApi {
  ResearchApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 20),
                headers: const <String, String>{
                  'Content-Type': 'application/json',
                },
              ),
            );

  final Dio _dio;
  final Map<String, String> _userQueries = {}; // Store queries for user jobs

  Future<String> startResearch({
    required String query,
    required String userId,
  }) async {
    // For demo, return a fake jobId immediately
    final jobId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    _userQueries[jobId] = query;
    return jobId;
  }

  Future<ResearchJob> getJobStatus(String jobId) async {
    // Demo data for MVP
    if (jobId.startsWith('demo')) {
      return _getDemoJobStatus(jobId);
    }

    // For user queries, simulate progress
    return _getSimulatedJobStatus(jobId);
  }

  ResearchJob _getSimulatedJobStatus(String jobId) {
    // Extract timestamp from jobId
    final parts = jobId.split('_');
    if (parts.length < 2) {
      return ResearchJob(
        jobId: jobId,
        query: 'Unknown query',
        status: 'running',
        createdAt: DateTime.now(),
      );
    }

    final timestamp = int.tryParse(parts[1]) ?? DateTime.now().millisecondsSinceEpoch;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final elapsed = DateTime.now().difference(createdAt).inSeconds;

    String status;
    if (elapsed < 5) {
      status = 'running';
    } else if (elapsed < 10) {
      status = 'agent_2_running';
    } else if (elapsed < 15) {
      status = 'agent_3_running';
    } else if (elapsed < 20) {
      status = 'agent_4_running';
    } else {
      status = 'completed';
    }

    return ResearchJob(
      jobId: jobId,
      query: _userQueries[jobId] ?? 'Your research query',
      status: status,
      createdAt: createdAt,
    );
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

    // For user queries, return dummy report
    return _getDummyReport(jobId);
  }

  FinalReport _getDummyReport(String jobId) {
    final query = _userQueries[jobId] ?? 'Your research query';

    // Generate a more detailed and query-specific summary
    final summary = _generateQuerySpecificSummary(query);

    return FinalReport(
      jobId: jobId,
      query: query,
      summary: summary,
      sections: _generateQuerySpecificSections(query),
      totalSources: 12,
    );
  }

  String _generateQuerySpecificSummary(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('ai') || lowerQuery.contains('artificial intelligence')) {
      return 'This comprehensive analysis of "${query}" reveals the transformative impact of artificial intelligence across industries. Our research shows AI adoption rates increasing by 270% since 2017, with natural language processing and machine learning leading innovation. Key findings include significant productivity gains, new ethical considerations, and emerging regulatory frameworks that will shape the future of AI implementation.';
    } else if (lowerQuery.contains('quantum') || lowerQuery.contains('computing')) {
      return 'The investigation into "${query}" demonstrates quantum computing\'s progression from theoretical concept to practical technology. Major breakthroughs in qubit stability and error correction have been achieved, with IBM\'s 1000+ qubit systems and Google\'s quantum supremacy demonstrations marking key milestones. The research identifies critical applications in cryptography, drug discovery, and optimization problems that classical computers cannot efficiently solve.';
    } else if (lowerQuery.contains('blockchain') || lowerQuery.contains('crypto')) {
      return 'Our detailed examination of "${query}" uncovers blockchain technology\'s evolution beyond cryptocurrency into enterprise solutions. Supply chain transparency, digital identity verification, and decentralized finance represent the most promising applications. The analysis reveals growing institutional adoption, with 81% of financial institutions exploring blockchain solutions, while highlighting scalability challenges and regulatory developments that will determine widespread adoption.';
    } else if (lowerQuery.contains('climate') || lowerQuery.contains('environment')) {
      return 'The research on "${query}" provides critical insights into global climate action strategies and environmental sustainability. Analysis shows renewable energy capacity growing 15% annually, with solar and wind power dominating new installations. Key findings include the economic viability of green technologies, policy frameworks driving adoption, and the urgent need for carbon capture and biodiversity preservation initiatives to meet international climate goals.';
    } else if (lowerQuery.contains('healthcare') || lowerQuery.contains('medical')) {
      return 'This thorough investigation of "${query}" demonstrates healthcare technology\'s rapid transformation through digital innovation. AI diagnostics accuracy reaching 94%, telemedicine adoption increasing 38-fold during the pandemic, and genomic medicine becoming clinically actionable represent major advancements. The research identifies critical challenges in data privacy, healthcare equity, and regulatory frameworks that must evolve alongside technological progress.';
    } else {
      return 'This comprehensive research report on "${query}" provides detailed analysis and insights based on extensive data collection and analysis. The investigation covers current trends, emerging developments, challenges, and future implications. Key findings reveal significant opportunities for innovation and growth, while identifying critical factors that will influence success in this domain. The analysis includes practical recommendations and strategic considerations for stakeholders.';
    }
  }

  List<ReportSection> _generateQuerySpecificSections(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('ai') || lowerQuery.contains('artificial intelligence')) {
      return [
        ReportSection(
          title: 'Current AI Landscape',
          content: 'The AI industry has reached a critical inflection point, with generative AI models like GPT-4 and DALL-E demonstrating unprecedented capabilities. Enterprise adoption has accelerated, with 55% of companies now using AI in production. Key sectors leading adoption include healthcare (diagnostic assistance), finance (fraud detection), and manufacturing (predictive maintenance). However, challenges in data quality, model interpretability, and computational requirements remain significant barriers.',
          sources: [
            'https://www.mckinsey.com/business-functions/mckinsey-digital/our-insights/the-state-of-ai-in-2023',
            'https://ai.google/research/understanding',
            'https://www.openai.com/research/gpt-4'
          ],
        ),
        ReportSection(
          title: 'Technical Breakthroughs',
          content: 'Recent advancements in transformer architectures, multimodal learning, and reinforcement learning have expanded AI capabilities. Self-supervised learning techniques have reduced data requirements by 90%, while edge AI deployment enables real-time processing on mobile devices. Quantum-enhanced machine learning shows promise for complex optimization problems, though practical implementation remains challenging.',
          sources: [
            'https://arxiv.org/abs/2201.08239',
            'https://ai.googleblog.com/2023/01/palm-2-technical-report.html',
            'https://www.nature.com/articles/s41586-023-06221-2'
          ],
        ),
        ReportSection(
          title: 'Industry Applications',
          content: 'AI applications span from autonomous vehicles and robotics to content creation and scientific research. In healthcare, AI achieves 94% accuracy in diabetic retinopathy detection, surpassing human experts. Financial institutions use AI for real-time fraud detection, preventing billions in losses annually. Creative industries leverage AI for content generation, while scientific research accelerates drug discovery through molecular property prediction.',
          sources: [
            'https://www.who.int/publications/i/item/9789240029200',
            'https://www.nature.com/articles/d41586-023-00029-3',
            'https://www.mckinsey.com/industries/financial-services/our-insights/ai-in-banking'
          ],
        ),
        ReportSection(
          title: 'Ethical and Regulatory Considerations',
          content: 'As AI systems become more powerful, ethical concerns around bias, privacy, and accountability intensify. Regulatory frameworks are emerging globally, with the EU AI Act classifying systems by risk level and the US considering comprehensive AI legislation. Industry self-regulation through frameworks like IEEE Ethically Aligned Design and Partnership on AI principles guides responsible development. Addressing the digital divide and ensuring equitable AI access remain critical challenges.',
          sources: [
            'https://artificialintelligenceact.eu/',
            'https://www.whitehouse.gov/ostp/ai-bill-of-rights/',
            'https://standards.ieee.org/industry-connections/ec/autonomous-systems/'
          ],
        ),
      ];
    } else if (lowerQuery.contains('quantum') || lowerQuery.contains('computing')) {
      return [
        ReportSection(
          title: 'Quantum Hardware Progress',
          content: 'Quantum computing has advanced from experimental systems to commercially available processors. IBM\'s 1000+ qubit Condor system and Google\'s Sycamore processor demonstrate quantum supremacy for specific algorithms. Superconducting qubits achieve coherence times exceeding 100 microseconds, while silicon-based quantum dots offer promising scalability. Error correction techniques have improved logical qubit fidelity to 99.9%, enabling more complex computations.',
          sources: [
            'https://quantum-computing.ibm.com/',
            'https://ai.google/research/quantum',
            'https://www.nature.com/articles/s41586-023-06096-3'
          ],
        ),
        ReportSection(
          title: 'Algorithm Development',
          content: 'Quantum algorithms for optimization, simulation, and cryptography are rapidly maturing. Variational quantum eigensolvers (VQE) solve molecular energy calculations, while quantum approximate optimization algorithms (QAOA) address combinatorial problems. Shor\'s algorithm threatens current cryptographic systems, necessitating post-quantum cryptography development. Quantum machine learning algorithms show exponential speedups for specific tasks.',
          sources: [
            'https://arxiv.org/abs/quant-ph/9508027',
            'https://quantum-journal.org/papers/q-2023-01-20-920/',
            'https://www.science.org/doi/10.1126/science.273.5278.1073'
          ],
        ),
        ReportSection(
          title: 'Practical Applications',
          content: 'Quantum computing finds applications in drug discovery, financial modeling, and supply chain optimization. Pharmaceutical companies use quantum simulation for protein folding prediction, potentially accelerating drug development. Financial institutions apply quantum algorithms for portfolio optimization and risk analysis. Logistics companies optimize routing problems that are computationally intractable for classical systems.',
          sources: [
            'https://www.nature.com/articles/s41586-023-06465-0',
            'https://www.mckinsey.com/industries/financial-services/our-insights/quantum-computing-in-finance',
            'https://www.pwc.com/us/en/industries/healthcare/library/quantum-computing.html'
          ],
        ),
        ReportSection(
          title: 'Challenges and Future Outlook',
          content: 'Scalability, error rates, and cryogenic cooling requirements present significant engineering challenges. Hybrid quantum-classical algorithms offer near-term value while full quantum advantage develops. Investment in quantum education and workforce development is crucial. The quantum computing market is projected to reach \$65 billion by 2030, with cloud-based quantum computing services becoming mainstream.',
          sources: [
            'https://www.mckinsey.com/business-functions/mckinsey-digital/our-insights/quantum-computings-potential-in-finance',
            'https://www.idc.com/getdoc.jsp?containerId=US48764322',
            'https://quantum-journal.org/papers/q-2023-05-25-1008/'
          ],
        ),
      ];
    } else {
      // Generic sections for other queries
      return [
        ReportSection(
          title: 'Current State Analysis',
          content: 'The current landscape of "${query}" shows dynamic evolution with significant technological, economic, and social implications. Market analysis reveals growing adoption rates and increasing investment in related technologies. Key stakeholders are actively shaping the future direction through innovation and strategic partnerships.',
          sources: [
            'https://www.example-research.com/current-state-analysis',
            'https://academic.journals.org/industry-report-2024',
            'https://market.intelligence.com/trends-analysis'
          ],
        ),
        ReportSection(
          title: 'Key Findings and Insights',
          content: 'Research reveals several critical insights about "${query}". Data analysis shows strong growth potential with compound annual growth rates exceeding industry averages. Emerging trends indicate shifting consumer preferences and technological capabilities that will redefine market dynamics. Competitive analysis highlights key success factors and strategic positioning requirements.',
          sources: [
            'https://research.institute.org/key-findings',
            'https://data.analytics.com/insights-report',
            'https://industry.analyst.com/market-research'
          ],
        ),
        ReportSection(
          title: 'Challenges and Opportunities',
          content: 'The investigation identifies both challenges and opportunities in "${query}". Regulatory considerations, technological limitations, and market saturation present hurdles, while emerging technologies, untapped markets, and strategic partnerships offer significant growth potential. Risk assessment and mitigation strategies are crucial for sustainable development.',
          sources: [
            'https://policy.research.org/challenges-analysis',
            'https://innovation.center.com/opportunities-report',
            'https://strategic.consulting.com/market-opportunities'
          ],
        ),
        ReportSection(
          title: 'Future Outlook and Recommendations',
          content: 'Looking ahead, "${query}" is positioned for substantial evolution driven by technological innovation and market forces. Strategic recommendations include investment in emerging technologies, partnership development, and regulatory compliance. Long-term success will depend on adaptability, innovation capacity, and market responsiveness.',
          sources: [
            'https://future.trends.org/outlook-report',
            'https://strategic.advisory.com/recommendations',
            'https://industry.forecast.com/future-prospects'
          ],
        ),
      ];
    }
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
