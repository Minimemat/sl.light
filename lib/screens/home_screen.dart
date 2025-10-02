import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/device_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../blocs/device_discovery_bloc.dart';
import '../widgets/device_card.dart';
import '../widgets/edit_devices_drawer.dart';
import '../widgets/device_add_flow.dart';
import '../widgets/device_add_widget.dart';
import '../widgets/manual_device_widget.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DeviceAddFlow _deviceAddFlow = DeviceAddFlow();

  @override
  void initState() {
    super.initState();
    // Load devices when the screen initializes
    context.read<DeviceBloc>().add(LoadDevices());
  }

  @override
  void dispose() {
    _deviceAddFlow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Devices')),
      drawer: _buildDrawer(),
      body: BlocBuilder<DeviceBloc, DeviceState>(
        builder: (context, state) {
          if (state is DeviceLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          } else if (state is DeviceLoaded) {
            if (state.devices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No devices connected',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first device or sync devices in the top left corner',
                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: state.devices.length,
              itemBuilder: (context, index) {
                final device = state.devices[index];
                return DeviceCard(
                  device: device,
                  onRefresh: () {
                    context.read<DeviceBloc>().add(LoadDevices());
                  },
                );
              },
            );
          } else if (state is DeviceError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading devices',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.red[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<DeviceBloc>().add(LoadDevices());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeviceDrawer,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header with logo
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            child: Column(
              children: [
                // StayLit logo
                Image.asset(
                  'lib/utils/staylit_logo_wide.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),

                // User email
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthAuthenticated) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_circle,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                state.user.email,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDrawerItem(
                  icon: Icons.edit,
                  title: 'Edit Devices',
                  onTap: _showEditDevicesDrawer,
                ),
                const SizedBox(height: 8),
                _buildDrawerItem(
                  icon: Icons.sync,
                  title: 'Sync Devices',
                  onTap: _syncDevices,
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.grey, height: 32),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: _logout,
                  textColor: Colors.red[400],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: textColor ?? Colors.white70, size: 20),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddDeviceDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            String? jwtToken;
            if (authState is AuthAuthenticated) {
              jwtToken = authState.user.jwtToken;
            }

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: MediaQuery.of(context).viewInsets,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DeviceAddWidget(
                          onDeviceSelected: (device) {
                            _deviceAddFlow.onDeviceTap(
                              context,
                              device,
                              jwtToken,
                              (device, jwt) {
                                context.read<DeviceBloc>().add(
                                  AddDevice(device, jwt: jwt),
                                );
                              },
                            );
                          },
                          onRefresh: () {
                            context.read<DeviceDiscoveryBloc>().add(
                              ClearDiscoveredDevices(),
                            );
                          },
                          jwtToken: jwtToken,
                        ),
                        ManualDeviceWidget(
                          onDeviceAdded: (ip, name) {
                            _deviceAddFlow.onManualAdd(
                              context,
                              ip,
                              name,
                              jwtToken,
                              (device, jwt) {
                                context.read<DeviceBloc>().add(
                                  AddDevice(device, jwt: jwt),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditDevicesDrawer() {
    Navigator.pop(context); // Close the main drawer first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EditDevicesDrawer(),
    );
  }

  void _syncDevices() {
    Navigator.pop(context); // Close the drawer

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<DeviceBloc>().add(
        SyncWithWordPress(authState.user.jwtToken),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Syncing devices with WordPress...'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _logout() {
    Navigator.pop(context); // Close the drawer

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthLogoutRequested());
              // Immediately navigate to welcome screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
