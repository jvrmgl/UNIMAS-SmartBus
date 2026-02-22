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
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search reports',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ReportStatus>(
                      value: _filterStatus,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Status',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All'),
                        ),
                        ...ReportStatus.values.map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(
                              status
                                  .toString()
                                  .split('.')
                                  .last
                                  .toUpperCase(),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _filterStatus = value);
                      },
                    ),
                  ],
                ),
              ),
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
                              subtitle: Text(report.description),
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
}
