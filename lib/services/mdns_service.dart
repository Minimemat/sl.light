import 'dart:async';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';

class MdnsService {
  /// Check if MDNS is supported on the current platform
  bool get isSupported {
    // MDNS works well on mobile platforms, limited support on Windows
    return !Platform.isWindows;
  }

  /// Stream-based WLED device discovery that emits devices as they're found
  Stream<Map<String, String>> discoverWledDevicesStream({
    Duration timeout = const Duration(seconds: 10),
  }) async* {
    // Check if running on Windows - MDNS has limited support
    if (Platform.isWindows) {
      print(
        'MDNS: Windows detected - MDNS may not work reliably, consider manual IP entry',
      );
    }

    print('MDNS: Starting WLED device discovery stream...');
    MDnsClient? client;

    try {
      client = MDnsClient();
      print('MDNS: Starting client...');
      await client.start();
      print('MDNS: Looking for _wled._tcp.local services...');

      await for (final PtrResourceRecord ptr
          in client
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer('_wled._tcp.local'),
              )
              .timeout(
                timeout,
                onTimeout: (sink) {
                  print('MDNS: Timeout reached, closing sink');
                  sink.close();
                },
              )) {
        print('MDNS: Found PTR record: ${ptr.domainName}');

        try {
          await for (final SrvResourceRecord srv
              in client.lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
              )) {
            print('MDNS: Found SRV record for ${srv.target}');

            try {
              await for (final IPAddressResourceRecord ip
                  in client.lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(srv.target),
                  )) {
                print('MDNS: Found IP address: ${ip.address.address}');
                final deviceName = ptr.domainName.replaceAll(
                  '.wled._tcp.local',
                  '',
                );

                final device = {
                  'name': deviceName,
                  'ip': ip.address.address,
                  'mac':
                      '', // MDNS doesn't provide MAC, will be filled by network discovery if needed
                };

                print(
                  'MDNS: Yielding device: $deviceName at ${ip.address.address}',
                );
                yield device;
              }
            } catch (e) {
              print('MDNS: Error resolving IP for ${srv.target}: $e');
              // Continue with next SRV record
            }
          }
        } catch (e) {
          print('MDNS: Error resolving SRV for ${ptr.domainName}: $e');
          // Continue with next PTR record
        }
      }
      print('MDNS: Discovery stream completed');
    } catch (e) {
      print('MDNS: Error during discovery: $e');
      // Don't rethrow, just log the error
    } finally {
      print('MDNS: Stopping client...');
      client?.stop();
    }
  }

  /// Legacy method for backward compatibility
  Future<List<Map<String, String>>> discoverWledDevices({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    print('MDNS: Starting WLED device discovery (legacy method)...');
    final List<Map<String, String>> devices = [];

    await for (final device in discoverWledDevicesStream(timeout: timeout)) {
      devices.add(device);
    }

    print('MDNS: Legacy discovery completed. Found ${devices.length} devices');
    return devices;
  }
}
