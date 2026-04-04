import 'package:flutter/foundation.dart';

class ApiConstants {
  const ApiConstants._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static List<String> get baseUrlCandidates {
    if (_configuredBaseUrl.isNotEmpty) {
      return <String>[_configuredBaseUrl];
    }

    if (kIsWeb) {
      return const <String>[
        'http://127.0.0.1:8000',
        'http://localhost:8000',
      ];
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return const <String>[
        'http://10.0.2.2:8000',
        'http://127.0.0.1:8000',
        'http://localhost:8000',
      ];
    }

    return const <String>[
      'http://127.0.0.1:8000',
      'http://localhost:8000',
    ];
  }

  static const String researchPath = '/research';
  static const String startResearchPath = '$researchPath/start';
  static const String healthPath = '/health';

  static String jobStatusPath(String jobId) => '$researchPath/$jobId';
  static String reportPath(String jobId) => '$researchPath/$jobId';

  // Google Gemini API Configuration
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'your-gemini-api-key-here', // Replace with actual key
  );
  static const String geminiModel = 'gemini-1.5-flash';
}
