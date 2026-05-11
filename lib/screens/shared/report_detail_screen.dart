import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.senderType,
  });

  final Report report;
  final ReportMessageSender senderType;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _adminNotesController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isSending = false;
  bool _isUpdating = false;
  bool _isStatusPanelExpanded = false;
  late ReportStatus _selectedStatus;
  late Report _currentReport;
  StreamSubscription<Report?>? _reportSubscription;
  String? _currentSenderId;
  String? _reporterEmail;
  String? _reporterName;
  final Map<String, String> _resolvedSenderEmails = {};
  final Map<String, String> _resolvedSenderNames = {};
  final Set<String> _resolvingSenderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _currentReport = widget.report;
    _reporterEmail = widget.report.reporterEmail;
    _reporterName = widget.report.reporterName;
    _selectedStatus = _currentReport.status;
    if (_currentReport.adminNotes != null) {
      _adminNotesController.text = _currentReport.adminNotes!;
    }
    _initializeCurrentSenderId();
    _resolveReporterIdentity();
    _reportSubscription = _firestoreService
        .getReportStream(widget.report.reportId)
        .listen((liveReport) {
      if (liveReport != null && mounted && !_isUpdating) {
        setState(() {
          _currentReport = liveReport;
          _reporterEmail = liveReport.reporterEmail ?? _reporterEmail;
          _reporterName = liveReport.reporterName ?? _reporterName;
          _selectedStatus = liveReport.status;
          if (_adminNotesController.text.trim().isEmpty &&
              (liveReport.adminNotes ?? '').isNotEmpty) {
            _adminNotesController.text = liveReport.adminNotes!;
          }
        });
        _resolveReporterIdentity();
      }
    });
  }

  Future<void> _initializeCurrentSenderId() async {
    final senderId = await _getSenderId();
    if (mounted) {
      setState(() {
        _currentSenderId = senderId;
      });
    }
  }

  Future<void> _resolveReporterIdentity() async {
    if ((_reporterEmail ?? '').isNotEmpty) return;
    final reporterUid = _currentReport.reporterUid;
    if (reporterUid == null || reporterUid.isEmpty) return;

    final reporter = await _firestoreService.getUserData(reporterUid);
    if (!mounted || reporter == null) return;

    setState(() {
      _reporterEmail = reporter.email;
      _reporterName = reporter.fullName;
      _resolvedSenderEmails[reporter.uid] = reporter.email;
      _resolvedSenderNames[reporter.uid] = reporter.fullName;
    });
  }

  Future<void> _resolveSenderIdentity(String senderId) async {
    if (senderId.isEmpty) return;
    if (_resolvedSenderEmails.containsKey(senderId)) return;
    if (_resolvingSenderIds.contains(senderId)) return;

    _resolvingSenderIds.add(senderId);
    final user = await _firestoreService.getUserData(senderId);
    _resolvingSenderIds.remove(senderId);

    if (!mounted || user == null) return;
    setState(() {
      _resolvedSenderEmails[senderId] = user.email;
      _resolvedSenderNames[senderId] = user.fullName;
    });
  }

  String? _senderEmailForMessage(ReportMessage message) {
    if ((message.senderEmail ?? '').isNotEmpty) {
      return message.senderEmail;
    }

    final senderType = message.senderType;
    if (senderType == ReportMessageSender.student ||
        senderType == ReportMessageSender.guest) {
      return _reporterEmail;
    }

    final cached = _resolvedSenderEmails[message.senderId];
    if (cached == null && message.senderId.isNotEmpty) {
      _resolveSenderIdentity(message.senderId);
    }
    return cached;
  }

  String _senderLabelForMessage(ReportMessage message) {
    if ((message.senderName ?? '').isNotEmpty) {
      return message.senderName!;
    }

    final senderType = message.senderType;
    if (senderType == ReportMessageSender.student ||
        senderType == ReportMessageSender.guest) {
      return _reporterName ?? 'Student';
    }

    final cached = _resolvedSenderNames[message.senderId];
    if (cached == null && message.senderId.isNotEmpty) {
      _resolveSenderIdentity(message.senderId);
    }
    return cached ?? 'Admin';
  }

  @override
  void dispose() {
    _reportSubscription?.cancel();
    _messageController.dispose();
    _adminNotesController.dispose();
    super.dispose();
  }

  Future<String> _getSenderId() async {
    if (widget.senderType == ReportMessageSender.admin) {
      final authProvider = context.read<AuthProvider>();
      return authProvider.firebaseUser?.uid ?? 'admin';
    }
    return firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'student';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    final senderId = await _getSenderId();
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final senderEmail = authProvider.currentUser?.email ??
        firebase_auth.FirebaseAuth.instance.currentUser?.email;
    final senderName = authProvider.currentUser?.fullName ??
        (widget.senderType == ReportMessageSender.admin ? 'Admin' : 'Student');

    final message = ReportMessage(
      senderId: senderId,
      senderType: widget.senderType,
      senderEmail: senderEmail,
      senderName: senderName,
      message: text,
      createdAt: DateTime.now(),
    );

    final result = await _firestoreService.addReportMessage(
      reportId: _currentReport.reportId,
      message: message,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result == null) {
      _messageController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  Future<void> _updateStatus() async {
    setState(() => _isUpdating = true);
    final result = await _firestoreService.updateReportStatus(
      _currentReport.reportId,
      _selectedStatus,
      adminNotes: _adminNotesController.text.trim().isEmpty
          ? null
          : _adminNotesController.text.trim(),
    );
    if (!mounted) return;

    setState(() {
      _isUpdating = false;
      if (result == null) {
        _currentReport = _currentReport.copyWith(
          status: _selectedStatus,
          adminNotes: _adminNotesController.text.trim().isEmpty
              ? null
              : _adminNotesController.text.trim(),
          resolvedAt: DateTime.now(),
        );
      }
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report status updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        elevation: 0,
      ),
      body: Builder(
        builder: (context) {
          final report = _currentReport;

          return Column(
            children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category + Status row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.category
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                      color: _statusColor(report.status)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _statusColor(report.status)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        report.status
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(report.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Description
                Text(report.description),
                const SizedBox(height: 10),
                // Meta chips
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _metaChip(
                        context,
                        Icons.calendar_today,
                        _formatDate(report.createdAt)),
                    if (report.busId != null && report.busId!.isNotEmpty)
                      _metaChip(context, Icons.directions_bus,
                          'Bus: ${report.busId}'),
                    if (report.routeId != null && report.routeId!.isNotEmpty)
                      _metaChip(context, Icons.route,
                          'Route: ${report.routeId}'),
                    if ((_reporterEmail ?? report.reporterEmail ?? '').isNotEmpty)
                      _metaChip(
                        context,
                        Icons.alternate_email,
                        'Reporter: ${_reporterEmail ?? report.reporterEmail}',
                      ),
                  ],
                ),
                // Admin notes
                if (report.adminNotes != null && report.adminNotes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.admin_panel_settings,
                            size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            report.adminNotes!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Images
                if ((report.imageUrls ?? []).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: report.imageUrls!.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final url = report.imageUrls![index];
                        return GestureDetector(
                          onTap: () => _openImageViewer(url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.senderType == ReportMessageSender.admin)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: InkWell(
                onTap: () => setState(
                    () => _isStatusPanelExpanded = !_isStatusPanelExpanded),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Update Report Status',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      Icon(
                        _isStatusPanelExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (widget.senderType == ReportMessageSender.admin &&
              _isStatusPanelExpanded)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<ReportStatus>(
                    initialValue: _selectedStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                    ),
                    items: ReportStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(
                              status.toString().split('.').last.toUpperCase(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adminNotesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Admin Notes (optional)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : _updateStatus,
                      child: _isUpdating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Status'),
                    ),
                  ),
                ],
              ),
            ),
          // Chat header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  widget.senderType == ReportMessageSender.admin
                      ? 'Chat with ${_reporterEmail ?? 'Student'}'
                      : 'Chat with Admin',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ReportMessage>>(
              stream: _firestoreService.getReportMessagesStream(
                report.reportId,
              ),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('No replies yet',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length * 2 - 1, // Account for date separators
                  itemBuilder: (context, index) {
                    // Handle date separators
                    if (index % 2 == 1) {
                      final messageIndex = (index - 1) ~/ 2;
                      final currentMessage = messages[messageIndex];
                      final nextMessage = messages[messageIndex + 1];
                      
                      if (!_isSameDay(currentMessage.createdAt, nextMessage.createdAt)) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDateSeparator(nextMessage.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    final messageIndex = index ~/ 2;
                    final message = messages[messageIndex];
                    final isSentByCurrentUser =
                        _currentSenderId != null && message.senderId == _currentSenderId;
                    final senderEmail = _senderEmailForMessage(message);
                    final senderLabel = _senderLabelForMessage(message);
                    final identityText =
                      (senderEmail ?? '').isNotEmpty ? senderEmail! : senderLabel;
                    
                    return Column(
                      children: [
                        if (messageIndex == 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatDateSeparator(message.createdAt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: isSentByCurrentUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isSentByCurrentUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: isSentByCurrentUser
                                    ? const EdgeInsets.only(right: 4, bottom: 2)
                                    : const EdgeInsets.only(left: 4, bottom: 2),
                                child: Text(
                                  identityText,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.all(12),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isSentByCurrentUser
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft:
                                        Radius.circular(isSentByCurrentUser ? 12 : 2),
                                    bottomRight:
                                        Radius.circular(isSentByCurrentUser ? 2 : 12),
                                  ),
                                ),
                                child: Text(message.message),
                              ),
                              Padding(
                                padding: isSentByCurrentUser
                                    ? const EdgeInsets.only(right: 4)
                                    : const EdgeInsets.only(left: 4),
                                child: Text(
                                  _formatTime(message.createdAt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a reply...',
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isSending ? null : _sendMessage,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _isSending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                ),
                              )
                            : Icon(Icons.send,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.reviewed:
        return Colors.blue;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.rejected:
        return Colors.red;
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDateSeparator(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dt.year, dt.month, dt.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      final monthNames = [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      return '${monthNames[dt.month]} ${dt.day}';
    }
  }

  void _openImageViewer(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Photo'),
        ),
        body: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.network(url),
              ),
            ),
          ),
        ),
      ),
      fullscreenDialog: true,
    ));
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _metaChip(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
