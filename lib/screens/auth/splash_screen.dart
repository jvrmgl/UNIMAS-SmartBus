import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../constants/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _minDelayElapsed = false;
  bool _hasNavigated = false;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    // Enforce a minimum 2-second splash display time.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _minDelayElapsed = true);
        _tryNavigate();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AuthProvider>();
    if (_authProvider != provider) {
      _authProvider?.removeListener(_tryNavigate);
      _authProvider = provider;
      _authProvider?.addListener(_tryNavigate);
    }
  }

  @override
  void dispose() {
    // Remove the listener when this screen is disposed.
    _authProvider?.removeListener(_tryNavigate);
    super.dispose();
  }

  void _tryNavigate() {
    if (!mounted || _hasNavigated) return;
    final authProvider = _authProvider;
    if (authProvider == null) return;

    // Wait until both the minimum delay has passed and Firebase + Firestore
    // have finished restoring the session.
    if (!_minDelayElapsed || !authProvider.isInitialized) return;

    final userRole = authProvider.currentUser?.role;

    if (authProvider.isAuthenticated) {
      if (userRole == UserRole.student) {
        _hasNavigated = true;
        Navigator.of(context).pushReplacementNamed('/student');
      } else if (userRole == UserRole.driver) {
        _hasNavigated = true;
        Navigator.of(context).pushReplacementNamed('/driver');
      } else if (userRole == UserRole.admin) {
        _hasNavigated = true;
        Navigator.of(context).pushReplacementNamed('/admin');
      } else {
        // Authenticated but no recognised role — fall back to guest view.
        _hasNavigated = true;
        Navigator.of(context).pushReplacementNamed('/guest');
      }
    } else {
      // Not logged in — open the guest map view.
      _hasNavigated = true;
      Navigator.of(context).pushReplacementNamed('/guest');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.directions_bus,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            // App Title
            Text(
              'UNIMAS SmartBus',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Real-Time Bus Tracking',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
