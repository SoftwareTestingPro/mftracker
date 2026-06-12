import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'core/theme.dart';
import 'presentation/screens/login_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: mftrackerApp(),
    ),
  );
}

class mftrackerApp extends StatelessWidget {
  const mftrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mutual Fund Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}
