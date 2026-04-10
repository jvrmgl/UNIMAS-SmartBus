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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _minDelayElapsed = false;
  bool _hasNavigated = false;
  AuthProvider? _authProvider;
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

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
    _authProvider?.removeListener(_tryNavigate);
    _animCtrl.dispose();
    super.dispose();
  }

  void _tryNavigate() {
    if (!mounted || _hasNavigated) return;
    final authProvider = _authProvider;
    if (authProvider == null) return;
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
        _hasNavigated = true;
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else {
      _hasNavigated = true;
        Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              Color(0xFF0D47A1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
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
                        size: 72,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'UNIMAS SmartBus',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Real-Time Bus Tracking',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 56),
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2.5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
