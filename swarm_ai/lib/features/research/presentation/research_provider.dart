import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/research_api.dart';
import '../domain/research_model.dart';

final researchApiProvider = Provider<ResearchApi>((ref) {
  return ResearchApi();
});

final researchQueryProvider = StateProvider<String>((ref) => '');
final activeJobIdProvider = StateProvider<String?>((ref) => null);

final _jobRefreshTickerProvider = StreamProvider.family<int, String>((ref, jobId) {
  return Stream<int>.periodic(const Duration(seconds: 2), (tick) => tick).asBroadcastStream();
});

final jobStatusProvider = FutureProvider.family<ResearchJob, String>((ref, jobId) async {
  ref.watch(_jobRefreshTickerProvider(jobId));
  final api = ref.watch(researchApiProvider);
  return api.getJobStatus(jobId);
});

final reportProvider = FutureProvider.family<FinalReport, String>((ref, jobId) async {
  final api = ref.watch(researchApiProvider);
  return api.getReport(jobId);
});
