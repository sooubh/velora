class ResearchJob {
  const ResearchJob({
    required this.jobId,
    required this.query,
    required this.status,
    required this.createdAt,
    this.progress = 0,
    this.phase = '',
    this.message,
    this.errorMessage,
    this.logs = const <String>[],
    this.agents = const <AgentProgress>[],
  });

  final String jobId;
  final String query;
  final String status;
  final DateTime createdAt;
  final int progress;
  final String phase;
  final String? message;
  final String? errorMessage;
  final List<String> logs;
  final List<AgentProgress> agents;

  factory ResearchJob.fromJson(Map<String, dynamic> json) {
    final rawAgents = json['agents'];
    final rawLogs = json['logs'];
    return ResearchJob(
      jobId: (json['job_id'] ?? json['jobId'] ?? '').toString(),
      query: (json['query'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
        progress: json['progress'] is int
          ? json['progress'] as int
          : int.tryParse((json['progress'] ?? '').toString()) ?? 0,
        phase: (json['phase'] ?? '').toString(),
        message: json['message']?.toString(),
      errorMessage: json['error_message']?.toString(),
      logs: rawLogs is List
          ? rawLogs.map((log) => log.toString()).toList(growable: false)
          : const <String>[],
      agents: rawAgents is List
          ? rawAgents
                .whereType<Map<String, dynamic>>()
                .map(AgentProgress.fromJson)
                .toList(growable: false)
          : const <AgentProgress>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'job_id': jobId,
      'query': query,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'progress': progress,
      'phase': phase,
      'message': message,
      'error_message': errorMessage,
      'logs': logs,
      'agents': agents.map((agent) => agent.toJson()).toList(growable: false),
    };
  }
}

class AgentProgress {
  const AgentProgress({
    required this.agentName,
    required this.status,
    required this.message,
  });

  final String agentName;
  final String status;
  final String message;

  factory AgentProgress.fromJson(Map<String, dynamic> json) {
    return AgentProgress(
      agentName: (json['agent_name'] ?? json['agentName'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'agent_name': agentName,
      'status': status,
      'message': message,
    };
  }
}

class ReportSection {
  const ReportSection({
    required this.title,
    required this.content,
    this.sources = const <String>[],
  });

  final String title;
  final String content;
  final List<String> sources;

  factory ReportSection.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];

    return ReportSection(
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      sources: rawSources is List
          ? rawSources.map((source) => source.toString()).toList(growable: false)
          : const <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'content': content,
      'sources': sources,
    };
  }
}

class FinalReport {
  const FinalReport({
    required this.jobId,
    required this.query,
    required this.summary,
    required this.sections,
    required this.totalSources,
  });

  final String jobId;
  final String query;
  final String summary;
  final List<ReportSection> sections;
  final int totalSources;

  factory FinalReport.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    return FinalReport(
      jobId: (json['job_id'] ?? json['jobId'] ?? '').toString(),
      query: (json['query'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      sections: rawSections is List
          ? rawSections
                .whereType<Map<String, dynamic>>()
                .map(ReportSection.fromJson)
                .toList(growable: false)
          : const <ReportSection>[],
      totalSources: json['total_sources'] is int
          ? json['total_sources'] as int
          : int.tryParse((json['total_sources'] ?? '').toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'job_id': jobId,
      'query': query,
      'summary': summary,
      'sections': sections.map((section) => section.toJson()).toList(),
      'total_sources': totalSources,
    };
  }
}
