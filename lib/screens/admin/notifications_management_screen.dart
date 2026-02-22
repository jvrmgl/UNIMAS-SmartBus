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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AnnouncementProvider>().fetchAnnouncements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Notifications'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddNotificationDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Create Notification'),
      ),
      body: Consumer<AnnouncementProvider>(
        builder: (context, announcementProvider, _) {
          if (announcementProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (announcementProvider.announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a notification to inform all users',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcementProvider.announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcementProvider.announcements[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getAnnouncementColor(announcement.type),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getAnnouncementIcon(announcement.type),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    announcement.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        announcement.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(announcement.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: Colors.red)),
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
                    value: selectedType,
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This notification will be sent to all app users',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                              height: 1.3,
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
                    value: selectedType,
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
