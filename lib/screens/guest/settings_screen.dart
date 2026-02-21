import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../shared/edit_profile_screen.dart';

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
  bool _serviceAlerts = true;
  bool _busUpdates = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().addListener(_onAuthProviderChanged);
      context.read<AnnouncementProvider>().fetchAnnouncements();
    });
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthProviderChanged);
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
    await authProvider.signOut();
    if (mounted) {
      _showMessage('Logged out');
      _emailController.clear();
      _passwordController.clear();
      Navigator.of(context).pushNamedAndRemoveUntil('/guest', (route) => false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notifications'),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer<AnnouncementProvider>(
              builder: (context, announcementProvider, _) {
                if (announcementProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (announcementProvider.announcements.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No announcements'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: announcementProvider.announcements.length,
                  itemBuilder: (context, index) {
                    final announcement = announcementProvider.announcements[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              announcement.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              announcement.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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
              final hasUnread = announcementProvider.announcements.isNotEmpty;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      _showNotificationsDialog();
                    },
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 8,
                      top: 8,
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
                _buildSectionTitle('Notifications'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Service alerts'),
                        subtitle: const Text('Delays, closures, announcements'),
                        value: _serviceAlerts,
                        onChanged: (value) {
                          setState(() {
                            _serviceAlerts = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Bus updates'),
                        subtitle: const Text('Nearby buses and stops'),
                        value: _busUpdates,
                        onChanged: (value) {
                          setState(() {
                            _busUpdates = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Appearance'),
                Card(
                  child: SwitchListTile(
                    title: const Text('Dark mode'),
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.setDarkMode(value);
                    },
                  ),
                ),
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
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white),
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
                  _buildSectionTitle('Notifications'),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Service alerts'),
                          subtitle: const Text('Delays, closures, announcements'),
                          value: _serviceAlerts,
                          onChanged: (value) {
                            setState(() {
                              _serviceAlerts = value;
                            });
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Bus updates'),
                          subtitle: const Text('Nearby buses and stops'),
                          value: _busUpdates,
                          onChanged: (value) {
                            setState(() {
                              _busUpdates = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Appearance'),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Dark mode'),
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.setDarkMode(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Staff Login'),
                  Card(
                    child: ExpansionTile(
                      title: const Text('Staff Login'),
                      subtitle: const Text('For drivers and administrators'),
                      leading: const Icon(Icons.badge),
                      initiallyExpanded: _isLoginExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _isLoginExpanded = expanded;
                        });
                      },
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Email Field
                              TextField(
                                controller: _emailController,
                                enabled: !_isLoading,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.email),
                                  hintText: 'Enter your email',
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              // Password Field
                              TextField(
                                controller: _passwordController,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      );
                                    },
                                  ),
                                  hintText: 'Enter your password',
                                ),
                                obscureText: _obscurePassword,
                              ),
                              const SizedBox(height: 24),
                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text('Login'),
                                ),
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
                      style: Theme.of(context).textTheme.bodySmall,
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
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
