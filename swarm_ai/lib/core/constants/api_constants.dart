class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = 'http://10.0.2.2:8000';
  static const String researchPath = '/research';

  static String jobStatusPath(String jobId) => '$researchPath/$jobId/status';
  static String reportPath(String jobId) => '$researchPath/$jobId/report';
}
