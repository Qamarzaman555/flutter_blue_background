import 'dart:typed_data';

/// A single BLE advertisement discovered during a scan.
///
/// This is emitted on the [FlutterBlueBackground.scanResults] stream. Some
/// fields are platform-dependent (see field docs) because Android and iOS
/// expose different information in their discovery callbacks.
class BleScanResult {
  BleScanResult({
    required this.deviceId,
    this.name,
    this.rssi,
    this.txPowerLevel,
    this.connectable,
    this.manufacturerData,
    this.serviceUuids = const [],
    this.serviceData = const {},
    this.timestampMillis,
  });

  /// Stable identifier for the device.
  ///
  /// - Android: the hardware MAC address (e.g. `AA:BB:CC:DD:EE:FF`).
  /// - iOS: the `CBPeripheral.identifier` UUID string. iOS never exposes the
  ///   MAC address; this id is what you pass back to connect/reconnect.
  final String deviceId;

  /// Advertised device name / local name, if present in the advertisement.
  final String? name;

  /// Received signal strength indicator, in dBm. Closer to 0 is stronger.
  final int? rssi;

  /// Transmit power level advertised by the device, if present.
  final int? txPowerLevel;

  /// Whether the device advertises itself as connectable.
  ///
  /// Available on Android (API 26+). On iOS this is derived from
  /// `CBAdvertisementDataIsConnectable` when present, otherwise null.
  final bool? connectable;

  /// Raw manufacturer-specific data from the advertisement.
  ///
  /// On Android the leading two bytes are the company identifier (little
  /// endian). On iOS this is the raw `CBAdvertisementDataManufacturerDataKey`
  /// value, which also begins with the company identifier.
  final Uint8List? manufacturerData;

  /// Service UUIDs advertised by the device (lower-cased strings).
  final List<String> serviceUuids;

  /// Service data keyed by service UUID string.
  final Map<String, Uint8List> serviceData;

  /// Discovery timestamp in milliseconds since epoch, when available.
  final int? timestampMillis;

  factory BleScanResult.fromMap(Map<dynamic, dynamic> map) {
    final rawServiceData = map['serviceData'] as Map<dynamic, dynamic>?;
    return BleScanResult(
      deviceId: map['deviceId']?.toString() ?? '',
      name: map['name'] as String?,
      rssi: (map['rssi'] as num?)?.toInt(),
      txPowerLevel: (map['txPowerLevel'] as num?)?.toInt(),
      connectable: map['connectable'] as bool?,
      manufacturerData: _toBytes(map['manufacturerData']),
      serviceUuids: (map['serviceUuids'] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          const [],
      serviceData: rawServiceData == null
          ? const {}
          : rawServiceData.map(
              (key, value) => MapEntry(
                key.toString().toLowerCase(),
                _toBytes(value) ?? Uint8List(0),
              ),
            ),
      timestampMillis: (map['timestampMillis'] as num?)?.toInt(),
    );
  }

  static Uint8List? _toBytes(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List) return Uint8List.fromList(value.cast<int>());
    return null;
  }

  @override
  String toString() =>
      'BleScanResult(deviceId: $deviceId, name: $name, rssi: $rssi, '
      'serviceUuids: $serviceUuids)';
}
