allowImageUploadimport CoreBluetooth
import Flutter
import Foundation
import os.log

/// Owns a `CBCentralManager` and translates a Dart `ScanConfig` map into a
/// CoreBluetooth scan, emitting discovered peripherals onto a Flutter
/// `EventChannel`.
///
/// CoreBluetooth only filters natively by service UUID. The remaining
/// cross-platform filters (`nameFilter` substring match and `rssiThreshold`)
/// are applied client-side in `didDiscover` so behaviour matches Android.
class BleScanner: NSObject {

    private let log = OSLog(subsystem: "com.sparkleo.flutter_blue_background", category: "BleScanner")

    private var centralManager: CBCentralManager!
    private var eventSink: FlutterEventSink?

    private(set) var isScanning = false

    // Pending scan parameters, applied once the central manager powers on.
    private var pendingServiceUuids: [CBUUID]?
    private var pendingOptions: [String: Any]?
    private var hasPendingScan = false

    // Client-side filters.
    private var nameFilter: String?
    private var skipUnnamedDevices = false
    private var rssiThreshold: Int?

    override init() {
        super.init()
        // Use the main queue so event sink callbacks are delivered on the
        // platform thread Flutter expects.
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public API

    func startScan(_ config: [String: Any]) -> Bool {
        let serviceUuidStrings = (config["serviceUuids"] as? [String]) ?? []
        pendingServiceUuids = serviceUuidStrings.isEmpty
            ? nil
            : serviceUuidStrings.compactMap { CBUUID(string: $0) }

        nameFilter = (config["nameFilter"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        skipUnnamedDevices = (config["skipUnnamedDevices"] as? Bool) ?? false
        rssiThreshold = config["rssiThreshold"] as? Int

        var options: [String: Any] = [:]
        if let ios = config["ios"] as? [String: Any] {
            if let allowDuplicates = ios["allowDuplicates"] as? Bool {
                options[CBCentralManagerScanOptionAllowDuplicatesKey] = allowDuplicates
            }
            if let solicited = ios["solicitedServiceUuids"] as? [String], !solicited.isEmpty {
                options[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] =
                    solicited.compactMap { CBUUID(string: $0) }
            }
        }
        pendingOptions = options

        // Restart cleanly if already scanning.
        if centralManager.isScanning {
            centralManager.stopScan()
        }

        if centralManager.state == .poweredOn {
            beginScan()
            return true
        }

        // Defer until the central manager powers on.
        hasPendingScan = true
        os_log("Bluetooth not powered on yet; scan deferred", log: log, type: .info)
        return true
    }

    func stopScan() -> Bool {
        hasPendingScan = false
        if centralManager.isScanning {
            centralManager.stopScan()
        }
        isScanning = false
        nameFilter = nil
        skipUnnamedDevices = false
        rssiThreshold = nil
        return true
    }

    func dispose() {
        _ = stopScan()
        eventSink = nil
    }

    // MARK: - Internal

    private func beginScan() {
        centralManager.scanForPeripherals(
            withServices: pendingServiceUuids,
            options: pendingOptions
        )
        isScanning = true
        hasPendingScan = false
        os_log("Scan started", log: log, type: .info)
    }
}

// MARK: - CBCentralManagerDelegate

extension BleScanner: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn, hasPendingScan {
            beginScan()
        } else if central.state != .poweredOn {
            isScanning = false
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssi = RSSI.intValue

        // Client-side RSSI threshold. 127 means "unknown" per CoreBluetooth.
        if let threshold = rssiThreshold, rssi != 127, rssi < threshold {
            return
        }

        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = localName ?? peripheral.name

        // Drop unnamed devices when requested.
        if skipUnnamedDevices, (name?.isEmpty ?? true) {
            return
        }

        // Client-side name filter (substring, case-insensitive) for parity with Android.
        if let filter = nameFilter {
            guard let name = name,
                  name.range(of: filter, options: .caseInsensitive) != nil else {
                return
            }
        }

        var payload: [String: Any] = [
            "deviceId": peripheral.identifier.uuidString,
            "rssi": rssi,
            "timestampMillis": Int(Date().timeIntervalSince1970 * 1000),
        ]

        if let name = name {
            payload["name"] = name
        }

        if let txPower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            payload["txPowerLevel"] = txPower.intValue
        }

        if let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber {
            payload["connectable"] = connectable.boolValue
        }

        if let mfrData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            payload["manufacturerData"] = FlutterStandardTypedData(bytes: mfrData)
        }

        if let serviceUuids = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            payload["serviceUuids"] = serviceUuids.map { $0.uuidString.lowercased() }
        }

        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            var mapped: [String: FlutterStandardTypedData] = [:]
            for (uuid, data) in serviceData {
                mapped[uuid.uuidString.lowercased()] = FlutterStandardTypedData(bytes: data)
            }
            payload["serviceData"] = mapped
        }

        eventSink?(payload)
    }
}

// MARK: - FlutterStreamHandler

extension BleScanner: FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
