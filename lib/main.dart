import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ToZipApp());
}

class ToZipApp extends StatelessWidget {
  const ToZipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToZip',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}