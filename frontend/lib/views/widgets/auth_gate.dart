import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/views/screens/authetication_screens/login_screen.dart';
import 'package:kurskart/views/screens/main_screen.dart';

/// Decides what the app opens on: the nav shell for a restored session, the
/// login screen otherwise.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return auth.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // A failed session restore is not worth an error screen — the user can
      // simply sign in again.
      error: (_, _) => const LoginScreen(),
      data: (user) => user == null ? const LoginScreen() : const MainScreen(),
    );
  }
}
