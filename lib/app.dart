import 'package:flutter/material.dart';
import 'package:pixel_lens/core/theme/app_theme.dart';
import 'package:pixel_lens/router/app_router.dart';

class PixelLensApp extends StatelessWidget {
  const PixelLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PixelPalette',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
