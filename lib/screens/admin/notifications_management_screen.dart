import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/announcement_provider.dart';
import '../../models/announcement_model.dart';
import '../../services/firestore_service.dart';

class NotificationsManagementScreen extends StatefulWidget {
  const NotificationsManagementScreen({super.key});

  @override
  State<NotificationsManagementScreen> createState() =>
      _NotificationsManagementScreenState();
}

class _NotificationsManagementScreenState
    extends State<NotificationsManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // ── Auto-notification template metadata ─────────────────────────────────────
  static const _templateMeta = {
    'bus_approaching': {
      'displayName': 'Bus Approaching',
      'description': 'Sent to waiting students when their bus is 500 m away',
      'placeholders': '{busNumber}, {regNumber}, {stopName}',
    },
    'tap_out_reminder': {
      'displayName': 'Tap-Out Reminder',
      'description': 'Sent to passengers still on the bus after 30 min',
      'placeholders': '{elapsedMin}',
    },
    'shift_reminder': {
      'displayName': 'Shift End Reminder',
      'description': 'Sent to drivers with no GPS update for over 1 hour',
      'placeholders': '{busNumber}',
    },
    'shift_started': {
      'displayName': 'Shift Started',
      'description': "Sent to a driver when an admin activates their bus",
      'placeholders': '{adminName}, {busNumber}',
    },
  };

  static const _defaultTitles = {
    'bus_approaching': '\u{1F68C} Bus is approaching!',
    'tap_out_reminder': '\u23F0 Still on the bus?',
    'shift_reminder': '\u{1F68C} Did you forget to end your shift?',
    'shift_started': '\u{1F68C} Your shift has started!',
  };

  static const _defaultBodies = {
    'bus_approaching':
        'Bus {busNumber} ({regNumber}) is approaching {stopName}',
    'tap_out_reminder':
        "You've been on the bus for {elapsedMin} minutes. Tap out when you arrive!",
    'shift_reminder':
        'Bus {busNumber} has been active with no GPS update for over an hour. Please end your shift if you are done.',
    'shift_started':
        '{adminName} has activated Bus {busNumber}. Tap to begin driving.',
  };

  Map<String, Map<String, String>> _templates = {};
  bool _templatesLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AnnouncementProvider>().fetchAnnouncements();
      _loadTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Notifications'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddNotificationDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Create Notification'),
      ),
      body: Consumer<AnnouncementProvider>(
        builder: (context, announcementProvider, _) {
          final announcements = announcementProvider.announcements;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTemplatesSection(),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text('Manual Notifications',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (announcements.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${announcements.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (ctx) {
                    if (announcementProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (announcements.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a notification to inform all users',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: announcements.length,
                      itemBuilder: (context, index) {
                        final announcement = announcements[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              _getAnnouncementIcon(announcement.type),
                              color: _getAnnouncementColor(announcement.type),
                              size: 22,
                            ),
                            title: Text(
                              announcement.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${announcement.description}\n${_formatDate(announcement.createdAt)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'resend',
                                  child: Row(
                                    children: [
                                      Icon(Icons.send, size: 18),
                                      SizedBox(width: 8),
                                      Text('Resend'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style:
                                              TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditNotificationDialog(announcement);
                                } else if (value == 'resend') {
                                  _resendNotification(announcement);
                                } else if (value == 'delete') {
                                  _confirmDeleteNotification(announcement);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Auto-notification template helpers ───────────────────────────────────────

  Future<void> _loadTemplates() async {
    if (!mounted) return;
    setState(() => _templatesLoading = true);

    // Start with hardcoded defaults
    final templates = <String, Map<String, String>>{
      for (final key in _templateMeta.keys)
        key: {'title': _defaultTitles[key]!, 'body': _defaultBodies[key]!}
    };

    // Merge in any Firestore overrides
    final stored = await _firestoreService.getNotificationTemplates();
    for (final entry in stored.entries) {
      if (templates.containsKey(entry.key)) {
        if (entry.value['title']?.isNotEmpty == true) {
          templates[entry.key]!['title'] = entry.value['title']!;
        }
        if (entry.value['body']?.isNotEmpty == true) {
          templates[entry.key]!['body'] = entry.value['body']!;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _templates = templates;
      _templatesLoading = false;
    });
  }

  Widget _buildTemplatesSection() {
    return ExpansionTile(
      leading: const Icon(Icons.smart_toy_outlined),
      title: Text('Auto Notification Templates',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: const Text('Messages sent automatically by the system',
          style: TextStyle(fontSize: 12)),
      initiallyExpanded: false,
      trailing: _templatesLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: _templateMeta.entries.map((entry) {
              final id = entry.key;
              final meta = entry.value;
              final currentTitle =
                  _templates[id]?['title'] ?? _defaultTitles[id]!;
              final currentBody =
                  _templates[id]?['body'] ?? _defaultBodies[id]!;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(_templateIcon(id),
                      color: Theme.of(context).colorScheme.primary, size: 22),
                  title: Text(meta['displayName']!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '"$currentTitle"\n$currentBody',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit template',
                    onPressed: () => _showEditTemplateDialog(
                      id: id,
                      displayName: meta['displayName']!,
                      placeholders: meta['placeholders']!,
                      currentTitle: currentTitle,
                      currentBody: currentBody,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  IconData _templateIcon(String id) {
    switch (id) {
      case 'bus_approaching':
        return Icons.directions_bus;
      case 'tap_out_reminder':
        return Icons.timer_outlined;
      case 'shift_reminder':
        return Icons.warning_amber_outlined;
      case 'shift_started':
        return Icons.play_circle_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  void _showEditTemplateDialog({
    required String id,
    required String displayName,
    required String placeholders,
    required String currentTitle,
    required String currentBody,
  }) {
    final titleCtrl = TextEditingController(text: currentTitle);
    final bodyCtrl = TextEditingController(text: currentBody);
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit: $displayName'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notification Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: bodyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Message Body',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available placeholders:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        placeholders,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final nav = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              final error = await _firestoreService.updateNotificationTemplate(
                id,
                titleCtrl.text.trim(),
                bodyCtrl.text.trim(),
              );
              if (!mounted) return;
              nav.pop();
              if (error == null) {
                _loadTemplates();
                messenger.showSnackBar(const SnackBar(
                  content: Text('Template updated'),
                  backgroundColor: Colors.green,
                ));
              } else {
                messenger.showSnackBar(SnackBar(
                  content: Text('Error: $error'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddNotificationDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    AnnouncementType selectedType = AnnouncementType.emergency;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Notification'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AnnouncementType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Notification Type',
                      border: OutlineInputBorder(),
                    ),
                    items: AnnouncementType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(
                              _getAnnouncementIcon(type),
                              size: 20,
                              color: _getAnnouncementColor(type),
                            ),
                            const SizedBox(width: 12),
                            Text(type.toString().split('.').last.toUpperCase()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedType = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g., Bus Service Update',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Enter notification message...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This notification will be sent to all app users',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final announcement = Announcement(
                    announcementId:
                        'ann_${DateTime.now().millisecondsSinceEpoch}',
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    type: selectedType,
                    createdAt: DateTime.now(),
                    expiryDate: DateTime.now().add(const Duration(days: 30)),
                    affectedRoutes: [],
                    isActive: true,
                    createdBy: 'admin',
                  );

                  // Capture context-dependent objects before async gap
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final announcementProvider = context.read<AnnouncementProvider>();

                  final error =
                      await _firestoreService.createAnnouncement(announcement);

                  if (!mounted) return;
                  navigator.pop();

                  if (error == null) {
                    // List auto-refreshes — no snackbar to avoid context crashes.
                    announcementProvider.fetchAnnouncements();
                  } else {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNotificationDialog(Announcement announcement) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: announcement.title);
    final descriptionController =
        TextEditingController(text: announcement.description);
    AnnouncementType selectedType = announcement.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Notification'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AnnouncementType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: AnnouncementType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.toString().split('.').last.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedType = value!);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Message'),
                    maxLines: 4,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Update feature coming soon')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _resendNotification(Announcement announcement) {
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resend Notification'),
        content: Text(
            'Are you sure you want to resend "${announcement.title}" to all users?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(scaffoldContext);

              final error = await _firestoreService
                  .resendAnnouncementNotification(announcement.announcementId);

              if (!mounted) return;
              navigator.pop();

              if (error == null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Notification sent to all users'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Resend'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNotification(Announcement announcement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text('Are you sure you want to delete "${announcement.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capture context-dependent objects before async gap
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final announcementProvider = context.read<AnnouncementProvider>();

              final error = await _firestoreService
                  .deleteAnnouncement(announcement.announcementId);

              if (!mounted) return;
              navigator.pop();

              if (error == null) {
                // List auto-refreshes — no snackbar to avoid context crashes.
                announcementProvider.fetchAnnouncements();
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getAnnouncementColor(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.emergency:
        return Colors.red;
      case AnnouncementType.maintenance:
        return Colors.orange;
      case AnnouncementType.route:
        return Colors.blue;
      case AnnouncementType.service:
        return Colors.green;
    }
  }

  IconData _getAnnouncementIcon(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.emergency:
        return Icons.warning;
      case AnnouncementType.maintenance:
        return Icons.build;
      case AnnouncementType.route:
        return Icons.route;
      case AnnouncementType.service:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
