import 'package:flutter/material.dart';

/// Helper functions for common operations

/// Format time from DateTime
String formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Format date from DateTime
String formatDate(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year;
  return '$day/$month/$year';
}

/// Format date and time
String formatDateTime(DateTime dateTime) {
  return '${formatDate(dateTime)} ${formatTime(dateTime)}';
}

/// Calculate duration between two times
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else {
    return '${minutes}m';
  }
}

/// Get relative time string (e.g., "2 hours ago")
String getRelativeTime(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  
  if (difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return formatDate(dateTime);
  }
}

/// Validate email format
bool isValidEmail(String email) {
  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  return emailRegex.hasMatch(email);
}

/// Validate phone number format
bool isValidPhoneNumber(String phone) {
  final phoneRegex = RegExp(r'^[0-9]{10,13}$');
  return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[^\d]'), ''));
}

/// Show snackbar message
void showSnackbar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Show simple dialog
void showSimpleDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonText = 'OK',
  VoidCallback? onPressed,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: onPressed ?? () => Navigator.pop(context),
          child: Text(buttonText),
        ),
      ],
    ),
  );
}

/// Show confirmation dialog
void showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  required VoidCallback onConfirm,
  String cancelText = 'Cancel',
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

/// Calculate percentage
double calculatePercentage(int current, int total) {
  if (total == 0) return 0;
  return (current / total) * 100;
}

/// Get color based on status
Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return Colors.green;
    case 'inactive':
      return Colors.grey;
    case 'pending':
      return Colors.orange;
    case 'resolved':
      return Colors.green;
    case 'rejected':
      return Colors.red;
    default:
      return Colors.blue;
  }
}

/// Generate unique ID
String generateUniqueId() {
  return DateTime.now().millisecondsSinceEpoch.toString();
}
