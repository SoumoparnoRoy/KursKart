import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurskart/views/widgets/auth_gate.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KursKart',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.white.withValues(alpha: 0.95)),
      ),
      home: const AuthGate(),
    );
  }
}
