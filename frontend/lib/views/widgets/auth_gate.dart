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
      // The token survived, so this is a connectivity problem rather than a
      // rejected session. Offer a retry instead of dropping the user at a login
      // screen they do not need to use.
      error: (e, _) => _RestoreFailed(
        message: '$e',
        onRetry: () => ref.invalidate(authProvider),
      ),
      data: (user) => user == null ? const LoginScreen() : const MainScreen(),
    );
  }
}

class _RestoreFailed extends StatelessWidget {
  const _RestoreFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
