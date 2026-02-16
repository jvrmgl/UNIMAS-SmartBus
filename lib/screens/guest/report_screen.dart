import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/report_model.dart';
import '../../services/device_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../shared/report_detail_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceService _deviceService = DeviceService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController;

  ReportCategory _category = ReportCategory.other;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _routeController = TextEditingController();
  final TextEditingController _busController = TextEditingController();
  String? _prefilledBusId; // Store actual busId when pre-filled from trip
  String? _prefilledRouteId; // Store actual routeId when pre-filled from trip
  bool _isSubmitting = false;
  bool _isUploading = false;
  List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // DeviceService is now a singleton and auto-initializes when needed
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get pre-filled data from route arguments (if navigating from trip)
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null && _busController.text.isEmpty) {
      // Only fill once on first load
      if (args['busId'] != null) {
        _prefilledBusId = args['busId'] as String;
      }
      if (args['busNumber'] != null) {
        // Show user-friendly bus number in the text field
        _busController.text = args['busNumber'] as String;
      }
      if (args['routeId'] != null) {
        _prefilledRouteId = args['routeId'] as String;
        _routeController.text = args['routeId'] as String;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _routeController.dispose();
    _busController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isEmpty) return;

    setState(() {
      _selectedImages = images;
    });
  }

  Future<List<String>> _uploadImages(String reportId) async {
    if (_selectedImages.isEmpty) return [];
    setState(() => _isUploading = true);

    final files = _selectedImages.map((image) => File(image.path)).toList();
    final urls = await _storageService.uploadReportImages(
      reportId: reportId,
      files: files,
    );

    setState(() => _isUploading = false);
    return urls;
  }

  Future<void> _submitReport() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showMessage('Please enter a description');
      return;
    }

    setState(() => _isSubmitting = true);

    final deviceId = await _deviceService.getDeviceId();
    final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}';
    final imageUrls = await _uploadImages(reportId);

    // Use prefilled busId if available, otherwise use text field value
    final busId = _prefilledBusId ?? 
                  (_busController.text.trim().isEmpty ? null : _busController.text.trim());
    
    // Use prefilled routeId if available, otherwise use text field value
    final routeId = _prefilledRouteId ?? 
                    (_routeController.text.trim().isEmpty ? null : _routeController.text.trim());

    final report = Report(
      reportId: reportId,
      studentId: deviceId,
      busId: busId,
      routeId: routeId,
      category: _category,
      description: description,
      imageUrls: imageUrls,
      status: ReportStatus.pending,
      createdAt: DateTime.now(),
    );

    final result = await _firestoreService.submitReport(report);
    if (!mounted) return;
    
    setState(() => _isSubmitting = false);

    if (result == null) {
      _descriptionController.clear();
      _routeController.clear();
      _busController.clear();
      _selectedImages = [];
      _showMessage('Report submitted');
      _tabController.animateTo(1);
    } else {
      _showMessage(result);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,          tabs: const [
            Tab(text: 'New Report'),
            Tab(text: 'My Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewReportTab(),
          _buildMyReportsTab(),
        ],
      ),
    );
  }

  Widget _buildNewReportTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<ReportCategory>(
          value: _category,
          decoration: const InputDecoration(
            labelText: 'Category',
          ),
          items: ReportCategory.values
              .map(
                (cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat.toString().split('.').last.toUpperCase()),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _category = value);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Describe the issue...',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _routeController,
          decoration: const InputDecoration(
            labelText: 'Route ID (optional)',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _busController,
          decoration: const InputDecoration(
            labelText: 'Bus ID (optional)',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attachments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: _isSubmitting || _isUploading ? null : _pickImages,
              icon: const Icon(Icons.photo_library),
              label: const Text('Add Photos'),
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(image.path),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _selectedImages.removeAt(index);
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReport,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _isUploading
                    ? const Text('Uploading...')
                    : const Text('Submit Report'),
          ),
        ),
      ],
    );
  }

  Widget _buildMyReportsTab() {
    return FutureBuilder<String>(
      future: _deviceService.getDeviceId(),
      builder: (context, snapshot) {
        final deviceId = snapshot.data;
        if (deviceId == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<Report>>(
          stream: _firestoreService.getReportsByStudentId(deviceId),
          builder: (context, reportSnapshot) {
            if (reportSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final reports = reportSnapshot.data ?? [];
            if (reports.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.report_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No reports yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submit a report from the other tab',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      report.category.toString().split('.').last.toUpperCase(),
                    ),
                    subtitle: Text(report.description),
                    trailing: Text(
                      report.status.toString().split('.').last.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReportDetailScreen(
                            report: report,
                            senderType: ReportMessageSender.guest,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
