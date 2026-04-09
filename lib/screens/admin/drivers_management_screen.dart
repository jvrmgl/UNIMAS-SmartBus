import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../providers/bus_provider.dart';
import '../../utils/app_navigator.dart';

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
  static final RegExp _emailRegex =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  bool _isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

  bool _isAllowedDriverEmailDomain(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith('@unimas.my') || e.endsWith('@unimas.edu.my');
  }

  void _showSafeSnackBar(
    BuildContext scaffoldContext,
    String message, {
    Color? backgroundColor,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

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

  Future<void> _refreshDriversSilently() async {
    final drivers = await _firestoreService.getUsersByRole(UserRole.driver);
    if (!mounted) return;
    setState(() {
      _drivers = drivers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Drivers'),
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
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(
                        'No drivers registered',
                        style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Drivers registered with the driver role appear here',
                        style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                                    backgroundColor: driver.isActive
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('Inactive',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                      Text(
                                        'ID: ${driver.uid}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
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
                                          : () => _confirmUnassignBus(driver),
                                      icon: Icon(
                                        !hasAssignedBus
                                            ? Icons.directions_bus
                                            : Icons.link_off,
                                        size: 18,
                                      ),
                                      label: Text(
                                        !hasAssignedBus
                                            ? 'Assign Bus'
                                            : 'Unassign Bus',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: !hasAssignedBus
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.orange.shade700,
                                        foregroundColor: Colors.white,
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
                  _showSafeSnackBar(
                    context,
                    'Driver updated successfully',
                    backgroundColor: Colors.green,
                  );
                  _loadDrivers();
                } else {
                  _showSafeSnackBar(
                    context,
                    error,
                    backgroundColor: Colors.red,
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
    bool isCreating = false;
    String? submitError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                    if (!_isValidEmail(value!)) return 'Invalid email format';
                    if (!_isAllowedDriverEmailDomain(value)) {
                      return 'Driver email must end with @unimas.my or @unimas.edu.my';
                    }
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
                if (submitError != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      submitError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: isCreating ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isCreating
                ? null
                : () async {
              if (formKey.currentState!.validate()) {
                setDialogState(() {
                  isCreating = true;
                  submitError = null;
                });

                AdminCreateUserResult result;
                try {
                  result = await _authService.createUserAsAdminWithResult(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                    fullName: nameController.text.trim(),
                    phoneNumber: '',
                    role: UserRole.driver,
                  );
                } catch (e) {
                  result = AdminCreateUserResult(
                    error: 'Failed to create driver account: $e',
                  );
                }

                if (!dialogContext.mounted) return;
                if (result.isSuccess && result.user != null) {
                  if (mounted) {
                    setState(() {
                      _drivers = [
                        result.user!,
                        ..._drivers.where((d) => d.uid != result.user!.uid),
                      ];
                    });
                  }
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  _showSafeSnackBar(
                    scaffoldContext,
                    'Driver account created successfully',
                    backgroundColor: Colors.green,
                  );
                  _refreshDriversSilently();
                } else {
                  setDialogState(() {
                    isCreating = false;
                    submitError = result.error ?? 'Failed to create driver account';
                  });
                  _showSafeSnackBar(
                    scaffoldContext,
                    submitError!,
                    backgroundColor: Colors.red,
                  );
                }
              }
            },
            child: isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
      ),
    );
  }

  void _showAssignBusDialog(User driver) {
    final scaffoldContext = context;
    final buses = context.read<BusProvider>().buses;
    final availableBuses = buses.where((bus) => bus.driverId == null).toList();
    final busProvider = context.read<BusProvider>();

    String? selectedBusId = availableBuses.isNotEmpty ? availableBuses.first.busId : null;
    bool isAssigning = false;
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
                  initialValue: selectedBusId,
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
              onPressed: isAssigning ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isAssigning || availableBuses.isEmpty || selectedBusId == null
                  ? null
                  : () async {
                      setDialogState(() => isAssigning = true);
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

                      _showSafeSnackBar(
                        scaffoldContext,
                        error ?? 'Bus assigned to ${driver.fullName}',
                        backgroundColor: error == null ? Colors.green : Colors.red,
                      );
                      if (error == null) {
                        busProvider.updateBusInList(
                          selectedBus.copyWith(
                            driverId: driver.uid,
                            driverName: driver.fullName,
                            lastUpdated: DateTime.now(),
                          ),
                        );
                        _refreshDriversSilently();
                        busProvider.fetchBuses();
                      } else {
                        setDialogState(() => isAssigning = false);
                      }
                    },
              child: isAssigning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUnassignBus(User driver) {
    final scaffoldContext = context;
    final busProvider = context.read<BusProvider>();
    final buses = busProvider.buses;
    final assignedBus = buses.where((b) => b.driverId == driver.uid).firstOrNull;

    if (assignedBus == null) {
      _showSafeSnackBar(
        scaffoldContext,
        'No bus assigned to this driver',
      );
      return;
    }

    final isOnActiveShift = assignedBus.isActive;
    bool isUnassigning = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Unassign Bus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove Bus ${assignedBus.busNumber} (${assignedBus.registrationNumber}) from ${driver.fullName}?',
            ),
            if (isOnActiveShift) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This bus is currently on an active shift. Unassigning will end the shift and take the bus offline.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: isUnassigning ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isUnassigning
                ? null
                : () async {
              setDialogState(() => isUnassigning = true);
              final navigator = Navigator.of(dialogContext);

              final error = await _firestoreService
                  .removeDriverFromBus(assignedBus.busId);

              if (!dialogContext.mounted) return;
              navigator.pop();
              if (!mounted) return;

              _showSafeSnackBar(
                scaffoldContext,
                error ??
                    'Bus ${assignedBus.busNumber} unassigned from ${driver.fullName}',
                backgroundColor: error == null ? Colors.green : Colors.red,
              );
              if (error == null) {
                busProvider.updateBusInList(
                  assignedBus.copyWith(
                    driverId: null,
                    driverName: null,
                    isActive: false,
                    currentOccupancy: 0,
                    lastUpdated: DateTime.now(),
                  ),
                );
                _refreshDriversSilently();
                busProvider.fetchBuses();
              } else {
                setDialogState(() => isUnassigning = false);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white),
            child: isUnassigning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unassign'),
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
              _showSafeSnackBar(
                scaffoldContext,
                error ?? 'Driver deleted successfully',
                backgroundColor: error == null ? Colors.green : Colors.red,
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
