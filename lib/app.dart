import 'package:go_router/go_router.dart';
import 'screens/splash/splash_screen.dart';
// Issuance routes removed as requested
import 'screens/checkpoint/checkpoint_scan_screen.dart';
import 'screens/checkpoint/checkpoint_face_screen.dart';
import 'screens/checkpoint/checkpoint_progress_screen.dart';
import 'screens/checkpoint/checkpoint_result_screen.dart';
import 'screens/tamper/tamper_demo_screen.dart';
import 'screens/history/scan_history_screen.dart';
import 'screens/about/about_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Checkpoint Flow ───────────────────────────────────────────────────
      GoRoute(
        path: '/checkpoint/scan',
        name: 'checkpoint-scan',
        builder: (_, __) => const CheckpointScanScreen(),
      ),
      GoRoute(
        path: '/checkpoint/face',
        name: 'checkpoint-face',
        builder: (_, state) {
          final docId = state.uri.queryParameters['docId'] ?? '';
          final docunetResult = state.uri.queryParameters['docunetResult'] ?? '';
          return CheckpointFaceScreen(documentId: docId, docunetResult: docunetResult);
        },
      ),
      GoRoute(
        path: '/checkpoint/progress',
        name: 'checkpoint-progress',
        builder: (_, state) {
          final docId = state.uri.queryParameters['docId'] ?? '';
          final facePhoto = state.uri.queryParameters['livePhoto'] ?? '';
          final docPhoto = state.uri.queryParameters['docPhoto'] ?? '';
          final docunetResult = state.uri.queryParameters['docunetResult'] ?? '';
          
          return CheckpointProgressScreen(
            documentId: docId,
            facePhotoPath: facePhoto,
            docPhotoPath: docPhoto,
            docunetResult: docunetResult,
          );
        },
      ),
      GoRoute(
        path: '/checkpoint/result',
        name: 'checkpoint-result',
        builder: (_, state) {
          final extra = state.extra;
          return CheckpointResultScreen(result: extra);
        },
      ),

      // ── Tamper Demo ───────────────────────────────────────────────────────
      GoRoute(
        path: '/tamper',
        name: 'tamper',
        builder: (_, __) => const TamperDemoScreen(),
      ),

      // ── History ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (_, __) => const ScanHistoryScreen(),
      ),

      // ── About ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (_, __) => const AboutScreen(),
      ),
    ],
  );
}
