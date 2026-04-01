import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/firebase_auth_service.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/research/presentation/home_screen.dart';
import '../features/research/presentation/progress_screen.dart';
import '../features/research/presentation/report_screen.dart';

class AppRouter {
  AppRouter({FirebaseAuthService? authService})
      : _authService = authService ?? FirebaseAuthService();

  final FirebaseAuthService _authService;

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(_authService.authStateChanges()),
    redirect: (context, state) {
      final User? user = _authService.getCurrentUser();
      final String location = state.uri.path;

      if (user == null && location != '/login' && location != '/') {
        return '/login';
      }

      if (user != null && (location == '/login' || location == '/')) {
        return '/home';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/progress/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId'] ?? '';
          return ProgressScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/report/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId'] ?? '';
          return ReportScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
