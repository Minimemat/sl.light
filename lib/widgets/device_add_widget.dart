import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/device_discovery_bloc.dart';

class DeviceAddWidget extends StatefulWidget {
  final Function(Map<String, String>) onDeviceSelected;
  final VoidCallback? onRefresh;
  final String? jwtToken;

  const DeviceAddWidget({
    super.key,
    required this.onDeviceSelected,
    this.onRefresh,
    this.jwtToken,
  });

  @override
  State<DeviceAddWidget> createState() => _DeviceAddWidgetState();
}

class _DeviceAddWidgetState extends State<DeviceAddWidget> {
  @override
  void initState() {
    super.initState();
    // Automatically start device discovery when widget is first displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DeviceDiscoveryBloc>().add(
          StartDeviceDiscovery(jwtToken: widget.jwtToken),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceDiscoveryBloc, DeviceDiscoveryState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, state),
            const SizedBox(height: 16),
            _buildContent(context, state),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, DeviceDiscoveryState state) {
    return const Text(
      'Find Devices',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildContent(BuildContext context, DeviceDiscoveryState state) {
    if (state is DeviceDiscoveryInitial) {
      return _buildInitialState(context);
    } else if (state is DeviceDiscoveryLoading) {
      return _buildLoadingState(context);
    } else if (state is DeviceDiscoverySuccess) {
      return _buildSuccessState(context, state);
    } else if (state is DeviceDiscoveryError) {
      return _buildErrorState(context, state);
    }

    return const SizedBox.shrink();
  }

  Widget _buildInitialState(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.wifi_find, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        const Text(
          'Device Discovery',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Scanning for WLED devices on your network...',
          style: TextStyle(fontSize: 16, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Searching for devices...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(
    BuildContext context,
    DeviceDiscoverySuccess state,
  ) {
    if (state.devices.isEmpty) {
      return Column(
        children: [
          if (state.isDiscovering) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Searching for devices...',
              style: TextStyle(color: Colors.white70),
            ),
          ] else ...[
            const Icon(Icons.devices_other, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'No devices found',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure your WLED devices are powered on and connected to the same network.',
              style: TextStyle(fontSize: 14, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        if (state.isDiscovering)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Searching...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ...state.devices.map((device) => _buildDeviceCard(device)),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, DeviceDiscoveryError state) {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(
          'Discovery Error',
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.message,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            context.read<DeviceDiscoveryBloc>().add(
              StartDeviceDiscovery(jwtToken: widget.jwtToken),
            );
          },
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(Map<String, String> device) {
    final ip = device['ip'] ?? '';
    final name = device['name'] ?? '';
    final mac = device['mac'] ?? '';

    // Use provided name or generate one with new convention
    String deviceName = name.isNotEmpty ? name : 'Lit House-Unknown';
    if (name.isEmpty && mac.isNotEmpty) {
      final macPrefix = mac.length >= 6
          ? mac.substring(0, 6).toUpperCase()
          : mac.toUpperCase();
      deviceName = 'Lit House-$macPrefix';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: const Color.fromARGB(255, 32, 32, 32),
      elevation: 2,
      child: ListTile(
        title: Text(
          deviceName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('IP: $ip'),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.lightbulb_outline,
            color: Colors.blue,
            size: 24,
          ),
        ),
        trailing: const Icon(Icons.add_circle_outline, color: Colors.blue),
        onTap: () => widget.onDeviceSelected(device),
      ),
    );
  }
}
