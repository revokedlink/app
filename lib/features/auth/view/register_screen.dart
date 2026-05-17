import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../store/auth_store.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

                const Text('Create an account').textCenter.semiBold.x2Large,
                const SizedBox(height: 4),
                const Text(
                  'Enter your details below to get started',
                ).textCenter.muted,
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
                  placeholder: const Text('Create a password'),
                  obscureText: true,
                  features: [InputFeature.passwordToggle()],
                ),
                const SizedBox(height: 14),

                const Text('Confirm Password').semiBold,
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmPasswordController,
                  placeholder: const Text('Confirm your password'),
                  obscureText: true,
                  features: [InputFeature.passwordToggle()],
                ),
                const SizedBox(height: 20),

                Observer(
                  builder: (_) => PrimaryButton(
                    onPressed: authStore.isLoading
                        ? null
                        : () => _handleRegister(authStore),
                    child: authStore.isLoading
                        ? const CircularProgressIndicator(size: 16)
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 20),

                const Divider(child: Text('OR')),
                const SizedBox(height: 20),

                OutlineButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Sign in instead'),
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

  Future<void> _handleRegister(AuthStore store) async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      return;
    }
    final success = await store.register(
      _emailController.text.trim(),
      _passwordController.text,
      _confirmPasswordController.text,
    );
    if (success && mounted) {
      context.go(AppRoutes.vault);
    }
  }
}
