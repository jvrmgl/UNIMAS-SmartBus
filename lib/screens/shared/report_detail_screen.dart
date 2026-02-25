import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/device_service.dart';
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
  final DeviceService _deviceService = DeviceService();
  bool _isSending = false;
  bool _isUpdating = false;
  bool _isStatusPanelExpanded = false;
  late ReportStatus _selectedStatus;
  late Report _currentReport;
  StreamSubscription<Report?>? _reportSubscription;

  @override
  void initState() {
    super.initState();
    _currentReport = widget.report;
    _selectedStatus = _currentReport.status;
    if (_currentReport.adminNotes != null) {
      _adminNotesController.text = _currentReport.adminNotes!;
    }
    _reportSubscription = _firestoreService
        .getReportStream(widget.report.reportId)
        .listen((liveReport) {
      if (liveReport != null && mounted && !_isUpdating) {
        setState(() {
          _currentReport = liveReport;
          _selectedStatus = liveReport.status;
          if (_adminNotesController.text.trim().isEmpty &&
              (liveReport.adminNotes ?? '').isNotEmpty) {
            _adminNotesController.text = liveReport.adminNotes!;
          }
        });
      }
    });
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
    return _deviceService.getDeviceId();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    final senderId = await _getSenderId();
    if (!mounted) return;

    final message = ReportMessage(
      senderId: senderId,
      senderType: widget.senderType,
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
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
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
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
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
                    value: _selectedStatus,
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
                  'Chatting with Reporter',
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
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isAdmin =
                        message.senderType == ReportMessageSender.admin;
                    return Align(
                      alignment: isAdmin
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: Radius.circular(isAdmin ? 12 : 2),
                            bottomRight: Radius.circular(isAdmin ? 2 : 12),
                          ),
                        ),
                        child: Text(message.message),
                      ),
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
