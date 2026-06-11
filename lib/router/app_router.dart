import 'package:go_router/go_router.dart';
import 'package:pixel_lens/features/canvas/presentation/canvas_screen.dart';
import 'package:pixel_lens/features/project/presentation/asset_list_screen.dart';
import 'package:pixel_lens/features/project/presentation/home_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const project = '/project/:projectId';
  static const asset = '/project/:projectId/asset/:assetId';

  static String projectPath(String projectId) => '/project/$projectId';
  static String assetPath(String projectId, String assetId) =>
      '/project/$projectId/asset/$assetId';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.project,
      builder: (_, state) => AssetListScreen(
        projectId: state.pathParameters['projectId']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.asset,
      builder: (_, state) => CanvasScreen(
        projectId: state.pathParameters['projectId'],
        assetId: state.pathParameters['assetId'],
      ),
    ),
  ],
);
