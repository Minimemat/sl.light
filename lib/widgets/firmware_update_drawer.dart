import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../widgets/loading_overlay.dart';

class FirmwareUpdateDrawer extends StatefulWidget {
  final Device device;

  const FirmwareUpdateDrawer({super.key, required this.device});

  @override
  State<FirmwareUpdateDrawer> createState() => _FirmwareUpdateDrawerState();
}

class _FirmwareUpdateDrawerState extends State<FirmwareUpdateDrawer> {
  bool _loadingInfo = true;
  String? _deviceVersion;
  String? _latestTag;
  String? _assetName;
  Uri? _assetDownloadUrl;
  String? _error;

  bool _isDownloading = false;
  Uint8List? _firmwareBytes;
  double? _downloadProgress; // 0.0 - 1.0
  List<FileSystemEntity> _downloadedFiles = const [];

  final LoadingOverlay _overlay = LoadingOverlay();

  String _resolveDownloadFileName() {
    if (_assetName != null && _assetName!.isNotEmpty) return _assetName!;
    if (_assetDownloadUrl != null) {
      final segs = _assetDownloadUrl!.pathSegments;
      if (segs.isNotEmpty) return segs.last;
    }
    return 'firmware.bin';
  }

  bool _isFileAlreadyDownloaded(String fileName) {
    for (final f in _downloadedFiles) {
      final name = f.path.split(Platform.pathSeparator).last;
      if (name == fileName) return true;
    }
    return false;
  }

  Widget _buildStatusBody() {
    if (_loadingInfo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          LinearProgressIndicator(),
          SizedBox(height: 12),
          Text('Checking device and latest firmware...'),
        ],
      );
    }
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.red));
    }

    final List<Widget> children = [
      Row(
        children: [
          Expanded(
            child: Text('Device version: ${_deviceVersion ?? 'Unknown'}'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Text(
              'Latest available: ${_latestTag ?? 'Unknown'}${_assetName != null ? ' ($_assetName)' : ''}',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];

    if (_isUpToDate) {
      children.addAll(const [
        Icon(Icons.check_circle, color: Colors.green),
        SizedBox(height: 8),
        Text('Your device is up to date.'),
      ]);
    } else {
      final targetName = _resolveDownloadFileName();
      final already = _isFileAlreadyDownloaded(targetName);
      children.add(
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    (_assetDownloadUrl != null && !_isDownloading && !already)
                    ? _downloadFirmware
                    : null,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  already
                      ? 'Already downloaded'
                      : (_latestTag == null
                            ? 'Download'
                            : 'Download $_latestTag'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_firmwareBytes != null) ? _uploadFirmware : null,
                icon: const Icon(Icons.upload),
                label: const Text('Upload to device'),
              ),
            ),
          ],
        ),
      );
      if (_firmwareBytes != null) {
        children.addAll([
          const SizedBox(height: 8),
          Text(
            'Firmware ready: ${_assetName ?? 'file'} (${_firmwareBytes!.length} bytes)',
          ),
        ]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loadingInfo = true;
      _error = null;
    });
    try {
      final info = await _fetchDeviceInfo();
      final latest = await _fetchLatestRelease();
      await _refreshDownloadedFiles();
      if (!mounted) return;
      setState(() {
        _deviceVersion = info['ver']?.toString();
        _latestTag = latest['tag']?.toString();
        _assetName = latest['assetName']?.toString();
        _assetDownloadUrl = latest['downloadUrl'] as Uri?;
        _loadingInfo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingInfo = false;
      });
    }
  }

  Future<Directory> _getFirmwareDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/firmware');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _refreshDownloadedFiles() async {
    final dir = await _getFirmwareDir();
    final items = await dir.list().toList();
    items.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    if (mounted) {
      setState(() {
        _downloadedFiles = items;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchDeviceInfo() async {
    final uri = Uri.parse('http://${widget.device.ipAddress}/json/info');
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode} fetching device info');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchLatestRelease() async {
    // Direct link to latest firmware from staylit.lighting
    final downloadUrl =
        'https://staylit.lighting/wp-content/firmware/WLED_0.15.1_ESP32.bin';
    final uri = Uri.parse(downloadUrl);

    // Extract version from filename (WLED_0.15.1_ESP32.bin -> v0.15.1)
    String tag = 'latest';
    final versionMatch = RegExp(
      r'WLED_(\d+\.\d+\.\d+)_ESP32\.bin',
    ).firstMatch(downloadUrl);
    if (versionMatch != null) {
      tag = 'v${versionMatch.group(1)}';
    }

    return {
      'tag': tag,
      'assetName': 'WLED_0.15.1_ESP32.bin',
      'downloadUrl': uri,
    };
  }

  bool get _isUpToDate {
    // Always return false for testing - allows downloading latest firmware regardless of current version
    return false;

    // Original logic (commented out):
    // if (_deviceVersion == null || _latestTag == null) return false;
    // final dv = _deviceVersion!.replaceFirst(RegExp('^v'), '');
    // final lv = _latestTag!.replaceFirst(RegExp('^v'), '');
    // return dv == lv; // minimal equality check
  }

  Future<void> _downloadFirmware() async {
    if (_assetDownloadUrl == null) return;
    setState(() {
      _isDownloading = true;
      _error = null;
      _downloadProgress = 0;
    });
    try {
      final dir = await _getFirmwareDir();
      final fileName = _resolveDownloadFileName();
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'File already downloaded. Delete it to download again.',
              ),
            ),
          );
        }
        return;
      }

      final req = http.Request('GET', _assetDownloadUrl!);
      final streamed = await req.send().timeout(const Duration(minutes: 2));
      final contentLen = streamed.contentLength ?? 0;
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in streamed.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (contentLen > 0 && mounted) {
          setState(() {
            _downloadProgress = received / contentLen;
          });
        }
      }
      await sink.flush();
      await sink.close();

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _firmwareBytes = file.readAsBytesSync();
        _assetName = fileName;
      });
      await _refreshDownloadedFiles();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isDownloading = false;
        _downloadProgress = null;
      });
    }
  }

  Future<void> _uploadFirmware() async {
    if (_firmwareBytes == null) return;
    final ip = widget.device.ipAddress;
    try {
      _overlay.showOrUpdate(context, 'Uploading firmware to device...');
      final uri = Uri.parse('http://$ip/update');
      final req = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'update',
            _firmwareBytes!,
            filename: _assetName ?? 'wled.bin',
          ),
        );
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      if (streamed.statusCode != 200 && streamed.statusCode != 302) {
        throw Exception('HTTP ${streamed.statusCode} uploading firmware');
      }

      _overlay.showOrUpdate(context, 'Firmware uploaded. Triggering reboot...');
      try {
        // Best-effort reboot trigger; ignore errors (device will drop connection)
        await http
            .get(Uri.parse('http://$ip/reset'))
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 10));

      // Poll /json/info until version changes to latest or timeout
      final ok = await _waitForDevice(ip);
      _overlay.close();
      if (!mounted) return;
      if (ok) {
        setState(() {
          _deviceVersion = _latestTag?.replaceFirst(RegExp('^v'), '');
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Update successful')));
        Navigator.maybePop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device did not confirm update in time'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _overlay.close();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _waitForDevice(String ip) async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(deadline)) {
      try {
        _overlay.showOrUpdate(
          context,
          'Waiting for device to come back online...',
        );
        final info = await _fetchDeviceInfo();
        String normalize(String s) {
          final noV = s.replaceFirst(RegExp('^v', caseSensitive: false), '');
          final m = RegExp(r'^[0-9]+(?:\.[0-9]+){0,2}').firstMatch(noV);
          return m?.group(0) ?? noV;
        }

        final ver = normalize(info['ver']?.toString() ?? '');
        final latest = normalize(_latestTag ?? '');
        if (ver == latest) return true;
        final uptimeVal = info['uptime'];
        final uptime = uptimeVal is int
            ? uptimeVal
            : int.tryParse(uptimeVal?.toString() ?? '') ?? -1;
        if (uptime >= 0 && uptime < 120) return true;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
    }
    return false;
  }

  Future<void> _confirmDelete(File file) async {
    final name = file.path.split(Platform.pathSeparator).last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Remove $name from downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await file.delete();
        if (mounted) {
          setState(() {
            if (_assetName == name) {
              _assetName = null;
              _firmwareBytes = null;
            }
          });
        }
        await _refreshDownloadedFiles();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Firmware Update',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Recheck',
                  onPressed: _init,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusBody(),
            if (_isDownloading && _downloadProgress != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _downloadProgress!.clamp(0.0, 1.0),
              ),
              const SizedBox(height: 6),
              Text(
                'Downloading ${((_downloadProgress ?? 0) * 100).toStringAsFixed(0)}%',
              ),
            ],
            const SizedBox(height: 16),
            if (_downloadedFiles.isNotEmpty) ...[
              const Text('Downloaded files'),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _downloadedFiles.length,
                  itemBuilder: (context, index) {
                    final f = _downloadedFiles[index];
                    final name = f.path.split(Platform.pathSeparator).last;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      subtitle: Text('${f.statSync().size} bytes'),
                      onTap: () async {
                        final bytes = await File(f.path).readAsBytes();
                        setState(() {
                          _firmwareBytes = bytes;
                          _assetName = name;
                        });
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        onPressed: () async {
                          await _confirmDelete(File(f.path));
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }
}
