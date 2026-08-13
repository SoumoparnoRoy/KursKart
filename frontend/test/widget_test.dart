import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurskart/models/user.dart';
import 'package:kurskart/providers/auth_provider.dart';
import 'package:kurskart/services/auth_service.dart';
import 'package:kurskart/views/screens/authetication_screens/login_screen.dart';
import 'package:kurskart/views/screens/authetication_screens/register_screen.dart';
import 'package:kurskart/views/screens/main_screen.dart';
import 'package:kurskart/views/widgets/auth_gate.dart';

User _user() => User(
  id: '1',
  fullName: 'Ada Lovelace',
  email: 'ada@example.com',
  state: '',
  city: '',
  locality: '',
  password: '',
);

/// Secure storage cannot run in a widget test, so the gate is driven through a
/// stubbed notifier instead.
class _StubAuth extends AuthNotifier {
  _StubAuth(this._initial);

  final User? _initial;

  @override
  Future<User?> build() async => _initial;
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(overrides: overrides, child: MaterialApp(home: child));

void main() {
  group('RegisterScreen', () {
    testWidgets('rejects a short password', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));

      await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ada@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'short');

      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('requires email and password', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Enter your email'), findsWidgets);
      expect(find.text('Enter your password'), findsWidgets);
    });

    testWidgets('obscures the password field by default', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).at(1),
          matching: find.byType(TextField),
        ),
      );
      expect(field.obscureText, isTrue);
    });
  });

  group('AuthGate', () {
    testWidgets('shows the login screen when signed out', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthGate(),
          overrides: [authProvider.overrideWith(() => _StubAuth(null))],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);
    });

    testWidgets('shows the nav shell when a session is restored', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AuthGate(),
          overrides: [authProvider.overrideWith(() => _StubAuth(_user()))],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });

  group('AuthService', () {
    test('exposes the server message on failure', () {
      const e = AuthException('User not found with this email');
      expect(e.message, 'User not found with this email');
      expect(e.toString(), 'User not found with this email');
    });
  });

}
