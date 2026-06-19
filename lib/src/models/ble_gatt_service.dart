/// A discovered GATT characteristic on a connected device.
class BleGattCharacteristic {
  const BleGattCharacteristic({
    required this.uuid,
    this.properties = const [],
  });

  final String uuid;

  /// Property flags, e.g. `read`, `write`, `writeWithoutResponse`, `notify`,
  /// `indicate`.
  final List<String> properties;

  factory BleGattCharacteristic.fromMap(Map<dynamic, dynamic> map) {
    final rawProps = map['properties'];
    return BleGattCharacteristic(
      uuid: map['uuid'] as String,
      properties: rawProps is List
          ? rawProps.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

/// A discovered GATT service on a connected device.
class BleGattService {
  const BleGattService({
    required this.uuid,
    this.characteristics = const [],
  });

  final String uuid;
  final List<BleGattCharacteristic> characteristics;

  factory BleGattService.fromMap(Map<dynamic, dynamic> map) {
    final rawChars = map['characteristics'];
    return BleGattService(
      uuid: map['uuid'] as String,
      characteristics: rawChars is List
          ? rawChars
              .map((e) =>
                  BleGattCharacteristic.fromMap(e as Map<dynamic, dynamic>))
              .toList()
          : const [],
    );
  }
}
