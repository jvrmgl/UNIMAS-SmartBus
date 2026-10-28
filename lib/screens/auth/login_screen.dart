import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../constants/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  bool _obscurePassword = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({bool allowDeviceTransfer = false}) async {
    // Dismiss keyboard before doing anything so the dialog always renders
    // fully visible regardless of keyboard state.
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    if (!_emailPattern.hasMatch(email)) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      email: email,
      password: password,
      allowDeviceTransfer: allowDeviceTransfer,
    );

    if (!mounted) return;

    if (success) {
      final userRole = authProvider.currentUser?.role;
      if (userRole == UserRole.student) {
        Navigator.of(context).pushReplacementNamed('/student');
      } else if (userRole == UserRole.driver) {
        Navigator.of(context).pushReplacementNamed('/driver');
      } else if (userRole == UserRole.admin) {
        Navigator.of(context).pushReplacementNamed('/admin');
      } else {
        _showErrorDialog(
          'Your account role is not recognized. Please contact admin.',
        );
      }
      return;
    }

    if (authProvider.requiresDeviceTransfer && !allowDeviceTransfer) {
      final shouldTransfer = await _showDeviceTransferDialog();
      if (!mounted) return;
      if (shouldTransfer == true) {
        await _handleLogin(allowDeviceTransfer: true);
      }
      return;
    }

    _showErrorDialog(authProvider.error ?? 'Login failed');
  }

  Future<bool?> _showDeviceTransferDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Account to This Device?'),
        content: const Text(
          'This student account is linked to another device. Continue to transfer it to this device now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    FocusScope.of(context).unfocus();

    final sentEmail = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (!mounted || sentEmail == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check Your Email'),
        content: Text('Password reset link sent to $sentEmail.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Gradient Hero Header ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24, mq.size.height * 0.05, 24, 36),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      Color(0xFF0D47A1),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    // Logo container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'UNIMAS SmartBus',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Real-Time Bus Tracking',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form Section ─────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign in',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enter your credentials to continue',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 28),
                        // Email field
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined),
                            hintText: 'Enter your email',
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        // Password field
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(
                                    () => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            hintText: 'Enter your password',
                          ),
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 28),
                        // Sign In Button
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            return SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        // Forgot password
                        Center(
                          child: TextButton(
                            onPressed: _handleForgotPassword,
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/signup');
                            },
                            child: const Text('Create Student Account'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Students can self-register. Driver and admin accounts are created by admin.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: mq.padding.bottom + 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final TextEditingController _emailController;
  String? _inlineError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _inlineError = 'Please enter your email address.');
      return;
    }

    if (!_LoginScreenState._emailPattern.hasMatch(email)) {
      setState(() => _inlineError = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _inlineError = null;
      _isSubmitting = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(email);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(email);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _inlineError = authProvider.error ?? 'Unable to send reset email.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your account email. We will send a password reset link.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 8),
            Text(
              _inlineError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Link'),
        ),
      ],
    );
  }
}
