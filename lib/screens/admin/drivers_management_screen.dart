import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../providers/bus_provider.dart';

class DriversManagementScreen extends StatefulWidget {
  const DriversManagementScreen({super.key});

  @override
  State<DriversManagementScreen> createState() =>
      _DriversManagementScreenState();
}

class _DriversManagementScreenState extends State<DriversManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<User> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BusProvider>().fetchBuses();
    });
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    final drivers = await _firestoreService.getUsersByRole(UserRole.driver);
    if (!mounted) return;
    setState(() {
      _drivers = drivers;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Drivers'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrivers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDriverDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Driver'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drivers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No drivers registered',
                        style: TextStyle(
                            fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Drivers registered with the driver role appear here',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDrivers,
                  child: Consumer<BusProvider>(
                    builder: (context, busProvider, _) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _drivers.length,
                        itemBuilder: (context, index) {
                          final driver = _drivers[index];
                          // Check if driver has a bus assigned
                          final hasAssignedBus = busProvider.buses
                              .any((bus) => bus.driverId == driver.uid);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        driver.isActive ? Colors.blue : Colors.grey,
                                    child: Text(
                                      driver.fullName.isNotEmpty
                                          ? driver.fullName[0].toUpperCase()
                                          : '?',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        driver.fullName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!driver.isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('Inactive',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(driver.email),
                                      if (driver.phoneNumber.isNotEmpty)
                                        Text(driver.phoneNumber,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                      Text(
                                        'ID: ${driver.uid}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500]),
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
                                            Text('Edit Driver'),
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
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showEditDriverDialog(driver);
                                      } else if (value == 'delete') {
                                        _confirmDeleteDriver(driver);
                                      }
                                    },
                                  ),
                                ),
                                // Action button row
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: !hasAssignedBus
                                          ? () => _showAssignBusDialog(driver)
                                          : null,
                                      icon: Icon(
                                        !hasAssignedBus
                                            ? Icons.directions_bus
                                            : Icons.check,
                                        size: 18,
                                      ),
                                      label: Text(
                                        !hasAssignedBus
                                            ? 'Assign Bus'
                                            : 'Bus Assigned',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: !hasAssignedBus
                                            ? Colors.blue
                                            : Colors.grey[300],
                                        foregroundColor: !hasAssignedBus
                                            ? Colors.white
                                            : Colors.grey[600],
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }

  void _showEditDriverDialog(User driver) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: driver.fullName);
    final emailController = TextEditingController(text: driver.email);
    final phoneController = TextEditingController(text: driver.phoneNumber);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Driver'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Email is required';
                    if (!value!.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
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
              if (formKey.currentState!.validate()) {
                final error = await _firestoreService.updateUserProfile(
                  uid: driver.uid,
                  fullName: nameController.text.trim(),
                  email: emailController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                );
                
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                
                if (!mounted) return;
                if (error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Driver updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadDrivers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddDriverDialog() {
    final scaffoldContext = context;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Driver'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (!value!.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Temporary Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (value!.length < 6) return 'Min 6 characters';
                    return null;
                  },
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
              if (formKey.currentState!.validate()) {
                final error = await _authService.createUserAsAdmin(
                  email: emailController.text.trim(),
                  password: passwordController.text.trim(),
                  fullName: nameController.text.trim(),
                  phoneNumber: '',
                  role: UserRole.driver,
                );

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content:
                        Text(error ?? 'Driver account created successfully'),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );
                if (error == null) {
                  _loadDrivers();
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAssignBusDialog(User driver) {
    final scaffoldContext = context;
    final buses = context.read<BusProvider>().buses;
    final availableBuses = buses.where((bus) => bus.driverId == null).toList();

    String? selectedBusId = availableBuses.isNotEmpty ? availableBuses.first.busId : null;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Assign Bus'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Assign a bus to ${driver.fullName}'),
              const SizedBox(height: 12),
              if (availableBuses.isEmpty)
                const Text('No available buses to assign.')
              else
                DropdownButtonFormField<String>(
                  value: selectedBusId,
                  decoration: const InputDecoration(
                    labelText: 'Select Bus',
                    prefixIcon: Icon(Icons.directions_bus),
                  ),
                  items: availableBuses
                      .map(
                        (bus) => DropdownMenuItem<String>(
                          value: bus.busId,
                          child: Text('Bus ${bus.busNumber} (${bus.registrationNumber})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedBusId = value);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: availableBuses.isEmpty || selectedBusId == null
                  ? null
                  : () async {
                      final selectedBus = availableBuses.firstWhere(
                        (bus) => bus.busId == selectedBusId,
                      );
                      final error = await _firestoreService.assignDriverToBus(
                        busId: selectedBus.busId,
                        driverId: driver.uid,
                        driverName: driver.fullName,
                      );

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      if (!mounted) return;

                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        SnackBar(
                          content:
                              Text(error ?? 'Bus assigned to ${driver.fullName}'),
                          backgroundColor:
                              error == null ? Colors.green : Colors.red,
                        ),
                      );
                      if (error == null) {
                        context.read<BusProvider>().fetchBuses();
                        _loadDrivers();
                      }
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDriver(User driver) {
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Driver'),
        content: Text(
            'Are you sure you want to delete ${driver.fullName}? This removes both login access and profile data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authDeleteError = await _authService.deleteUserAuthByUidAsAdmin(driver.uid);

              final error = authDeleteError ??
                  await _firestoreService.deleteUserProfile(driver.uid);

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                SnackBar(
                  content: Text(error ?? 'Driver deleted successfully'),
                  backgroundColor: error == null ? Colors.green : Colors.red,
                ),
              );
              if (error == null) {
                context.read<BusProvider>().fetchBuses();
                _loadDrivers();
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
