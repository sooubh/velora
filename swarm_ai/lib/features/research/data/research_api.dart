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

  Future<String> startResearch({
    required String query,
    required String userId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.researchPath,
      data: <String, dynamic>{
        'query': query,
        'user_id': userId,
      },
    );

    final data = response.data;
    if (data == null || data['job_id'] == null) {
      throw StateError('Missing job_id in startResearch response');
    }

    return data['job_id'].toString();
  }

  Future<ResearchJob> getJobStatus(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.jobStatusPath(jobId),
    );

    final data = response.data;
    if (data == null) {
      throw StateError('Empty response in getJobStatus');
    }

    return ResearchJob.fromJson(data);
  }

  Future<FinalReport> getReport(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.reportPath(jobId),
    );

    final data = response.data;
    if (data == null) {
      throw StateError('Empty response in getReport');
    }

    return FinalReport.fromJson(data);
  }
}
