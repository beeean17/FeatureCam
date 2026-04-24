import 'package:flutter/material.dart';

import '../ui/camera_screen.dart';
import '../ui/camera_theme.dart';

class FeatureCamApp extends StatelessWidget {
  const FeatureCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FeatureCam',
      debugShowCheckedModeBanner: false,
      theme: FeatureCamTheme.dark,
      home: const CameraScreen(),
    );
  }
}
