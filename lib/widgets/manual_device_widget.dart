import 'package:flutter/material.dart';

class ManualDeviceWidget extends StatefulWidget {
  final Function(String ip, String name) onDeviceAdded;

  const ManualDeviceWidget({
    super.key,
    required this.onDeviceAdded,
  });

  @override
  State<ManualDeviceWidget> createState() => _ManualDeviceWidgetState();
}

class _ManualDeviceWidgetState extends State<ManualDeviceWidget> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 32),
          const Text(
            'Add Manually',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ipController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Device IP Address',
              prefixIcon: Icon(Icons.lan),
              hintText: '192.168.1.100',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'IP address is required';
              }
              if (!_isValidIpAddress(value.trim())) {
                return 'Please enter a valid IP address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              prefixIcon: Icon(Icons.edit),
              hintText: 'My WLED Device',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Device name is required';
              }
              if (value.trim().length < 2) {
                return 'Device name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleAddDevice,
            child: const Text('Add Device'),
          ),
        ],
      ),
    );
  }

  void _handleAddDevice() {
    if (_formKey.currentState?.validate() ?? false) {
      final ip = _ipController.text.trim();
      final name = _nameController.text.trim();
      widget.onDeviceAdded(ip, name);
      
      // Clear form after successful submission
      _ipController.clear();
      _nameController.clear();
    }
  }

  bool _isValidIpAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }
} 