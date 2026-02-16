import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/student_trip_model.dart';

class StudentTripDetailScreen extends StatelessWidget {
  final StudentTrip trip;

  const StudentTripDetailScreen({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            _buildStatusBadge(),
            const SizedBox(height: 24),

            // Bus Information Card
            _buildInfoCard(
              'Bus Information',
              [
                _buildInfoRow(Icons.directions_bus, 'Bus Number', trip.busNumber),
                _buildInfoRow(Icons.confirmation_number, 'Registration', trip.busRegistrationNumber),
                if (trip.routeName != null)
                  _buildInfoRow(Icons.route, 'Route', trip.routeName!),
              ],
            ),
            const SizedBox(height: 16),

            // Trip Timeline Card
            _buildInfoCard(
              'Trip Timeline',
              [
                _buildInfoRow(
                  Icons.login,
                  'Boarded At',
                  _formatDateTime(trip.boardedAt),
                ),
                if (trip.offBoardedAt != null)
                  _buildInfoRow(
                    Icons.logout,
                    'Off-Boarded At',
                    _formatDateTime(trip.offBoardedAt!),
                  ),
                if (trip.offBoardedAt != null)
                  _buildInfoRow(
                    Icons.timer,
                    'Duration',
                    trip.getFormattedDuration(),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Report Issue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/report',
                    arguments: {
                      'busId': trip.busId,
                      'busNumber': trip.busNumber,
                      'routeId': trip.routeId,
                      'tripId': trip.tripId,
                    },
                  );
                },
                icon: const Icon(Icons.report_problem),
                label: const Text('Report an Issue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Help Text
            Text(
              'Report any issues you experienced during this trip',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isActive = trip.status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.circle : Icons.check_circle,
            size: 16,
            color: isActive ? Colors.white : Colors.grey[700],
          ),
          const SizedBox(width: 8),
          Text(
            isActive ? 'Active Trip' : 'Completed',
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
  }
}
