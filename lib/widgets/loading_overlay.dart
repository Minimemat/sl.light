import 'package:flutter/material.dart';

class LoadingOverlay {
  OverlayEntry? _overlay;
  String _currentMessage = '';

  /// Show or update loading dialog
  void showOrUpdate(BuildContext context, String message) {
    if (_overlay == null) {
      _currentMessage = message;
      _overlay = OverlayEntry(
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(_currentMessage),
                ),
              ],
            ),
          ),
        ),
      );
      Overlay.of(context).insert(_overlay!);
    } else if (_currentMessage != message) {
      // Update the message and rebuild the overlay
      _currentMessage = message;
      _overlay!.markNeedsBuild();
    }
  }

  /// Close loading dialog
  void close() {
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
      _currentMessage = '';
    }
  }

  /// Dispose of overlay
  void dispose() {
    close();
  }
} 