import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../store/auth_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authStore = context.read<AuthStore>();

    return Scaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: const Text(
                        'R',
                      ).bold(color: Colors.black, fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Sign in to your account',
                ).textCenter.semiBold.x2Large,
                const SizedBox(height: 4),
                const Text('Enter your credentials below').textCenter.muted,
                const SizedBox(height: 28),

                Observer(
                  builder: (_) {
                    if (authStore.errorMessage != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Alert(
                          destructive: true,
                          leading: const Icon(BootstrapIcons.exclamation),
                          title: const Text('Error'),
                          content: Text(authStore.errorMessage!),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const Text('Email').semiBold,
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  placeholder: const Text('name@example.com'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                const Text('Password').semiBold,
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  placeholder: const Text('Password'),
                  obscureText: true,
                  features: [InputFeature.passwordToggle()],
                ),
                const SizedBox(height: 20),

                Observer(
                  builder: (_) => PrimaryButton(
                    onPressed: authStore.isLoading
                        ? null
                        : () => _handleLogin(authStore),
                    child: authStore.isLoading
                        ? const CircularProgressIndicator(size: 16)
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 20),

                const Divider(child: Text('OR')),
                const SizedBox(height: 20),

                OutlineButton(
                  onPressed: () => context.go(AppRoutes.register),
                  child: const Text('Create an account'),
                ),

                const SizedBox(height: 24),
                const Text(
                  'This is an experimental app. Use with caution.',
                ).textCenter.muted.xSmall,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin(AuthStore store) async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty)
      return;
    final success = await store.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (success && mounted) {
      context.go(AppRoutes.vault);
    }
  }
}
