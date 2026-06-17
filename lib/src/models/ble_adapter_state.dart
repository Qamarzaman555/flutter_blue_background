/// Cross-platform Bluetooth adapter (radio) state.
///
/// Values are aligned with [flutter_blue_plus] `BluetoothAdapterState` and map
/// from native platform APIs on both Android and iOS.
enum BleAdapterState {
  unknown,
  unsupported,
  unauthorized,
  off,
  turningOn,
  on,
  turningOff;

  /// Whether the adapter is powered on and ready for BLE operations.
  bool get isOn => this == BleAdapterState.on;

  /// Whether scanning can be started immediately.
  bool get canScan => this == BleAdapterState.on;

  /// Parses the string emitted by the native platform.
  factory BleAdapterState.fromNative(String? value) {
    if (value == null || value.isEmpty) return BleAdapterState.unknown;
    for (final state in BleAdapterState.values) {
      if (state.name == value) return state;
    }
    return BleAdapterState.unknown;
  }
}
