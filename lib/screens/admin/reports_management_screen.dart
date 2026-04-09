import 'package:flutter/material.dart';
import '../../models/report_model.dart';
import '../../services/firestore_service.dart';
import '../shared/report_detail_screen.dart';

class ReportsManagementScreen extends StatefulWidget {
  const ReportsManagementScreen({super.key});

  @override
  State<ReportsManagementScreen> createState() =>
      _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  ReportStatus? _filterStatus;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Report>>(
        stream: _firestoreService.getReportsStream(),
        builder: (context, snapshot) {
          final reports = snapshot.data ?? [];
          final query = _searchController.text.trim().toLowerCase();
          final filtered = reports.where((report) {
            final matchesStatus = _filterStatus == null
                ? true
                : report.status == _filterStatus;
            final matchesQuery = query.isEmpty
                ? true
                : report.description.toLowerCase().contains(query) ||
                    report.category
                        .toString()
                        .split('.')
                        .last
                        .toLowerCase()
                        .contains(query);
            return matchesStatus && matchesQuery;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search reports',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: [
                    _statusChip(null, 'All',
                        Theme.of(context).colorScheme.primary),
                    _statusChip(ReportStatus.pending, 'Pending', Colors.orange),
                    _statusChip(
                        ReportStatus.reviewed, 'Reviewed', Colors.blue),
                    _statusChip(
                        ReportStatus.resolved, 'Resolved', Colors.green),
                    _statusChip(
                        ReportStatus.rejected, 'Rejected', Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No reports found'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final report = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                report.category
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    report.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDateTime(report.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _statusColor(report.status)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _statusColor(report.status)
                                        .withValues(alpha: 0.45),
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
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(report.status),
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReportDetailScreen(
                                      report: report,
                                      senderType: ReportMessageSender.admin,
                                    ),
                                  ),
                                );
                              },
                            ),
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

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year $hour:$minute $period';
  }

  Widget _statusChip(ReportStatus? status, String label, Color color) {
    final isSelected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.normal,
            color: isSelected ? Colors.white : color,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterStatus = status),
        selectedColor: color,
        checkmarkColor: Colors.white,
        backgroundColor: color.withValues(alpha: 0.1),
        side: BorderSide(
          color: isSelected ? color : color.withValues(alpha: 0.4),
        ),
        showCheckmark: false,
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),
    );
  }
}
