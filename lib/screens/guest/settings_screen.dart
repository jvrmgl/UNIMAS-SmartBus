import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/notification_prefs_provider.dart';
import '../../providers/driver_shift_provider.dart';
import '../../services/smart_notification_service.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../constants/app_theme.dart';
import '../shared/edit_profile_screen.dart';
import '../../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isAwaitingRoleRouting = false;
  bool _isLoginExpanded = false;
  AuthProvider? _authProviderRef;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authProviderRef = context.read<AuthProvider>();
      _authProviderRef!.addListener(_onAuthProviderChanged);
      context.read<AnnouncementProvider>().fetchAnnouncements();
      final uid = _authProviderRef!.currentUser?.uid;
      if (uid != null) {
        context.read<NotificationPrefsProvider>().load(uid);
      }
    });
  }

  @override
  void dispose() {
    _authProviderRef?.removeListener(_onAuthProviderChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthProviderChanged() {
    if (!_isAwaitingRoleRouting || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    _isAwaitingRoleRouting = false;
    final userRole = user.role;

    if (userRole == UserRole.driver) {
      Navigator.of(context).pushNamedAndRemoveUntil('/driver', (route) => false);
    } else if (userRole == UserRole.admin) {
      Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
    } else {
      _showMessage('Access denied - Staff accounts only');
      authProvider.signOut();
    }
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success) {
      _isAwaitingRoleRouting = true;
      _onAuthProviderChanged();
    } else {
      _showMessage('The information entered is incorrect');
    }
  }

  void _handleLogout() async {
    final authProvider = context.read<AuthProvider>();
    final shiftProvider = context.read<DriverShiftProvider>();
    final notifPrefs = context.read<NotificationPrefsProvider>();
    // Capture navigator before async gaps to avoid deactivated-context errors.
    final nav = Navigator.of(context);

    // If a driver is on an active shift, end it cleanly so the bus goes
    // offline in Firestore before we lose auth credentials to do so.
    if (authProvider.currentUser?.role == UserRole.driver &&
        shiftProvider.isOnShift) {
      await shiftProvider.endShift();
    }
    // Wipe local shift state regardless of role so the next driver login
    // always starts with a clean slate on this device.
    shiftProvider.clearShiftState();
    // Reset notification prefs to defaults so the next user's preferences
    // are not influenced by this user's settings.
    notifPrefs.resetToDefaults();

    await authProvider.signOut();
    _emailController.clear();
    _passwordController.clear();
    nav.pushNamedAndRemoveUntil('/guest', (route) => false);
  }

  Widget _buildNotificationSettings({required bool isDriver}) {
    return Consumer<NotificationPrefsProvider>(
      builder: (context, prefs, _) => Card(
        clipBehavior: Clip.hardEdge,
        child: ExpansionTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Smart Notifications',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Push alerts & auto-detect preferences'),
          children: [
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Bus approaching'),
              subtitle: const Text(
                  'Alert when a bus nears your stop while you are waiting'),
              secondary: const Icon(Icons.directions_bus),
              value: prefs.busApproaching,
              onChanged: prefs.setBusApproaching,
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Tap-out reminder'),
              subtitle:
                  const Text('Remind me to tap out after 30 minutes on a bus'),
              secondary: const Icon(Icons.logout),
              value: prefs.tapOutReminder,
              onChanged: prefs.setTapOutReminder,
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Auto-detect waiting'),
              subtitle: const Text(
                  'Automatically mark me as waiting if I stay near a stop for '
                  '${SmartNotificationService.waitConfirmMinutes}+ minutes'),
              secondary: const Icon(Icons.access_time),
              value: prefs.autoDetectWaiting,
              onChanged: prefs.setAutoDetectWaiting,
            ),
            if (isDriver) ...[
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Shift-end reminder'),
                subtitle: const Text(
                    'Remind me to end my shift if no GPS update for 1 hour'),
                secondary: const Icon(Icons.timer_off),
                value: prefs.driverShiftReminder,
                onChanged: prefs.setDriverShiftReminder,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showNotificationsDialog() {
    showAppNotificationsSheet(context, 'student');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        actions: [
          Consumer<AnnouncementProvider>(
            builder: (context, announcementProvider, _) {
              final hasUnread = announcementProvider.hasVisibleAnnouncementsFor('student');
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        _showNotificationsDialog();
                      },
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        constraints: const BoxConstraints(
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final themeProvider = context.watch<ThemeProvider>();
          if (authProvider.isAuthenticated && authProvider.currentUser != null) {
            // User is logged in - show account info
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildNotificationSettings(
                  isDriver: authProvider.currentUser?.role == UserRole.driver,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Appearance'),
                _buildThemeSetting(themeProvider),
                const SizedBox(height: 24),
                _buildSectionTitle('Account'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoItem(
                        'Name',
                        authProvider.currentUser?.fullName ?? 'N/A',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        'Email',
                        authProvider.currentUser?.email ?? 'N/A',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        'Role',
                        authProvider.currentUser?.role.toString().split('.').last.toUpperCase() ?? 'N/A',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // User is not logged in - show login form
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationSettings(isDriver: false),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Appearance'),
                  _buildThemeSetting(themeProvider),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Staff Login'),
                  Card(
                    clipBehavior: Clip.hardEdge,
                    child: ExpansionTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text(
                        'For drivers and administrators',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: null,
                      initiallyExpanded: _isLoginExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() => _isLoginExpanded = expanded);
                      },
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _emailController,
                                enabled: !_isLoading,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  hintText: 'Enter your email',
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _passwordController,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                                  ),
                                  hintText: 'Enter your password',
                                ),
                                obscureText: _obscurePassword,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text('Login'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Students: No login needed, use the app as guest!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Expandable tile that lets the user pick Light / Dark / System.
  Widget _buildThemeSetting(ThemeProvider themeProvider) {
    final IconData modeIcon;
    final String modeLabel;
    if (themeProvider.isSystemMode) {
      modeIcon = Icons.settings_brightness;
      modeLabel = 'System default';
    } else if (themeProvider.isDarkMode) {
      modeIcon = Icons.dark_mode;
      modeLabel = 'Dark';
    } else {
      modeIcon = Icons.light_mode;
      modeLabel = 'Light';
    }
    return Card(
      clipBehavior: Clip.hardEdge,
      child: ExpansionTile(
        leading: Icon(modeIcon),
        title: const Text('App theme'),
        subtitle: Text('Change app theme  ·  $modeLabel'),
        children: [
          _themeOption(themeProvider, ThemeMode.light, Icons.light_mode,
              'Light', 'Always use light theme'),
          _themeOption(themeProvider, ThemeMode.dark, Icons.dark_mode,
              'Dark', 'Always use dark theme'),
          _themeOption(themeProvider, ThemeMode.system,
              Icons.settings_brightness, 'System default',
              'Follow your device settings'),
        ],
      ),
    );
  }

  Widget _themeOption(ThemeProvider provider, ThemeMode mode, IconData icon,
      String label, String description) {
    final isSelected = provider.themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryColor : null),
      title: Text(label),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
          : null,
      onTap: () => provider.setThemeMode(mode),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
