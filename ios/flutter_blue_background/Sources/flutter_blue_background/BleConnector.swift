import CoreBluetooth
import Flutter
import Foundation
import os.log

/// Manages GATT connections using the shared `CBCentralManager` from [BleScanner].
final class BleConnector: NSObject {

    private static let gapServiceUuid = CBUUID(string: "1801")
    private static let servicesChangedUuid = CBUUID(string: "2A05")
    private static let cccdUuid = CBUUID(string: "2902")

    private let log = OSLog(subsystem: "com.sparkleo.flutter_blue_background", category: "BleConnector")
    private weak var scanner: BleScanner?

    private var eventSink: FlutterEventSink?
    private var stateCache: [String: [String: Any]] = [:]

    private struct Session {
        var peripheral: CBPeripheral
        var config: [String: Any]
        var mtu: Int = 23
        var timeoutTimer: Timer?
        var discoverCompletion: (([[String: Any]]?) -> Void)?
        var mtuCompletion: ((Int) -> Void)?
    }

    private var sessions: [String: Session] = [:]
    private var discoverPendingCounts: [String: Int] = [:]

    init(scanner: BleScanner) {
        self.scanner = scanner
        super.init()
    }

    // MARK: - Public API

    func connect(deviceId: String, config: [String: Any]) -> Bool {
        guard let scanner = scanner else { return false }
        let central = scanner.sharedCentralManager
        guard scanner.isAdapterReady() else {
            emitState(
                deviceId: deviceId,
                state: "disconnected",
                errorMessage: "Bluetooth adapter is not ready"
            )
            return false
        }

        if stateCache[deviceId]?["state"] as? String == "connected" {
            return true
        }

        guard let peripheral = scanner.peripheral(for: deviceId) else {
            emitState(deviceId: deviceId, state: "disconnected", errorMessage: "Peripheral not found")
            return false
        }

        _ = disconnect(deviceId: deviceId, config: [:])

        var session = Session(peripheral: peripheral, config: config)
        sessions[deviceId] = session
        peripheral.delegate = self

        emitState(deviceId: deviceId, state: "connecting", mtu: session.mtu)

        var options: [String: Any] = [:]
        if let ios = config["ios"] as? [String: Any] {
            if let value = ios["notifyOnConnection"] as? Bool {
                options[CBConnectPeripheralOptionNotifyOnConnectionKey] = value
            }
            if let value = ios["notifyOnDisconnection"] as? Bool {
                options[CBConnectPeripheralOptionNotifyOnDisconnectionKey] = value
            }
            if let value = ios["notifyOnNotification"] as? Bool {
                options[CBConnectPeripheralOptionNotifyOnNotificationKey] = value
            }
            if #available(iOS 17.0, *) {
                if let value = ios["enableAutoReconnect"] as? Bool {
                    options[CBConnectPeripheralOptionEnableAutoReconnect] = value
                }
            }
        }

        central.connect(peripheral, options: options.isEmpty ? nil : options)

        let autoConnect = (config["autoConnect"] as? Bool) ?? false
        if !autoConnect, let millis = config["timeoutMillis"] as? Int, millis > 0 {
            let interval = TimeInterval(millis) / 1000.0
            let timer = Timer(timeInterval: interval, repeats: false) { [weak self] fired in
                fired.invalidate()
                guard let self = self else { return }
                if self.stateCache[deviceId]?["state"] as? String != "connected" {
                    os_log("Connection timeout for %{public}@", log: self.log, type: .info, deviceId)
                    _ = self.disconnect(deviceId: deviceId, config: [:])
                    self.emitState(
                        deviceId: deviceId,
                        state: "disconnected",
                        errorMessage: "Connection timeout"
                    )
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            session.timeoutTimer = timer
            sessions[deviceId] = session
        }

        return true
    }

    @discardableResult
    func disconnect(deviceId: String, config: [String: Any]) -> Bool {
        guard let scanner = scanner else { return false }
        guard var session = sessions[deviceId] else {
            emitState(deviceId: deviceId, state: "disconnected")
            return true
        }

        session.timeoutTimer?.invalidate()
        session.timeoutTimer = nil
        sessions[deviceId] = session

        emitState(deviceId: deviceId, state: "disconnecting", mtu: session.mtu)
        scanner.sharedCentralManager.cancelPeripheralConnection(session.peripheral)
        return true
    }

    func getConnectionState(deviceId: String) -> String {
        stateCache[deviceId]?["state"] as? String ?? "disconnected"
    }

    func getConnectedDeviceIds() -> [String] {
        stateCache.compactMap { key, value in
            value["state"] as? String == "connected" ? key : nil
        }
    }

    func requestMtu(deviceId: String, mtu: Int) -> Int {
        // iOS negotiates MTU automatically; return the cached value.
        sessions[deviceId]?.mtu ?? stateCache[deviceId]?["mtu"] as? Int ?? 23
    }

    func requestConnectionPriority(deviceId: String, priority: Int) {
        // Not supported on iOS.
    }

    func discoverServices(
        deviceId: String,
        timeoutMillis: Int,
        subscribeToServicesChanged: Bool
    ) -> [[String: Any]]? {
        guard var session = sessions[deviceId] else { return nil }
        guard session.peripheral.state == .connected else { return nil }

        var config = session.config
        config["subscribeToServicesChanged"] = subscribeToServicesChanged
        session.config = config
        sessions[deviceId] = session

        let semaphore = DispatchSemaphore(value: 0)
        var result: [[String: Any]]?

        session.discoverCompletion = { services in
            result = services
            semaphore.signal()
        }
        sessions[deviceId] = session
        discoverPendingCounts[deviceId] = 0

        session.peripheral.discoverServices(nil)

        let wait = DispatchTime.now() + .milliseconds(max(timeoutMillis, 1000))
        if semaphore.wait(timeout: wait) == .timedOut {
            sessions[deviceId]?.discoverCompletion = nil
            discoverPendingCounts.removeValue(forKey: deviceId)
            return nil
        }

        sessions[deviceId]?.discoverCompletion = nil
        return result
    }

    func dispose() {
        onBluetoothAdapterOff()
    }

    /// Emits disconnected for every active session when the adapter powers off.
    func onBluetoothAdapterOff() {
        for deviceId in sessions.keys {
            let session = sessions[deviceId]
            emitState(
                deviceId: deviceId,
                state: "disconnected",
                mtu: session?.mtu,
                errorMessage: "Bluetooth turned off"
            )
        }
        for deviceId in sessions.keys {
            sessions[deviceId]?.timeoutTimer?.invalidate()
        }
        sessions.removeAll()
        discoverPendingCounts.removeAll()
    }

    func detachSink() {
        eventSink = nil
    }

    // MARK: - Internal

    private func emitState(
        deviceId: String,
        state: String,
        mtu: Int? = nil,
        errorMessage: String? = nil,
        errorCode: Int? = nil
    ) {
        var payload: [String: Any] = [
            "deviceId": deviceId,
            "state": state,
        ]
        if let mtu = mtu ?? sessions[deviceId]?.mtu {
            payload["mtu"] = mtu
        }
        if let errorMessage = errorMessage {
            payload["errorMessage"] = errorMessage
        }
        if let errorCode = errorCode {
            payload["errorCode"] = errorCode
        }
        stateCache[deviceId] = payload
        eventSink?(payload)
    }

    private func mapServices(_ peripheral: CBPeripheral, filter: [String]?) -> [[String: Any]] {
        guard let services = peripheral.services else { return [] }
        let filterSet = filter.map { Set($0.map { $0.lowercased() }) }

        return services.compactMap { service in
            let uuid = service.uuid.uuidString.lowercased()
            if let filterSet = filterSet, !filterSet.isEmpty, !filterSet.contains(uuid) {
                return nil
            }
            let characteristics = (service.characteristics ?? []).map { characteristic -> [String: Any] in
                var props: [String] = []
                let p = characteristic.properties
                if p.contains(.read) { props.append("read") }
                if p.contains(.write) { props.append("write") }
                if p.contains(.writeWithoutResponse) { props.append("writeWithoutResponse") }
                if p.contains(.notify) { props.append("notify") }
                if p.contains(.indicate) { props.append("indicate") }
                return [
                    "uuid": characteristic.uuid.uuidString.lowercased(),
                    "properties": props,
                ]
            }
            return [
                "uuid": uuid,
                "characteristics": characteristics,
            ]
        }
    }

    private func subscribeServicesChanged(_ peripheral: CBPeripheral) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.gapServiceUuid }) else {
            return
        }
        guard let characteristic = service.characteristics?.first(where: {
            $0.uuid == Self.servicesChangedUuid
        }) else {
            return
        }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    private func completeDiscoveryIfReady(deviceId: String, peripheral: CBPeripheral) {
        guard let pending = discoverPendingCounts[deviceId], pending == 0 else { return }
        discoverPendingCounts.removeValue(forKey: deviceId)

        guard let session = sessions[deviceId] else { return }
        let filter = session.config["serviceUuids"] as? [String]
        let mapped = mapServices(peripheral, filter: filter)

        if let completion = session.discoverCompletion {
            completion(mapped)
        } else if session.config["subscribeToServicesChanged"] as? Bool ?? true {
            subscribeServicesChanged(peripheral)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BleConnector: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        guard sessions[deviceId] != nil else { return }

        if let error = error {
            sessions[deviceId]?.discoverCompletion?(nil)
            emitState(deviceId: deviceId, state: "connected", errorMessage: error.localizedDescription)
            return
        }

        guard let services = peripheral.services, !services.isEmpty else {
            sessions[deviceId]?.discoverCompletion?([])
            discoverPendingCounts.removeValue(forKey: deviceId)
            return
        }

        discoverPendingCounts[deviceId] = services.count
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let deviceId = peripheral.identifier.uuidString
        guard var pending = discoverPendingCounts[deviceId] else { return }
        pending -= 1
        discoverPendingCounts[deviceId] = pending
        if pending <= 0 {
            completeDiscoveryIfReady(deviceId: deviceId, peripheral: peripheral)
        }
    }
}

// MARK: - CBCentralManagerDelegate hooks (via BleScanner)

extension BleConnector {
    func handleDidConnect(_ peripheral: CBPeripheral) {
        let deviceId = peripheral.identifier.uuidString
        guard var session = sessions[deviceId] else { return }

        peripheral.delegate = self
        session.timeoutTimer?.invalidate()
        session.timeoutTimer = nil
        session.mtu = 185
        sessions[deviceId] = session

        emitState(deviceId: deviceId, state: "connected", mtu: 185)

        if session.config["discoverServicesOnConnect"] as? Bool ?? true {
            discoverPendingCounts[deviceId] = 0
            peripheral.discoverServices(nil)
        }
    }

    func handleDidFailToConnect(_ peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        emitState(
            deviceId: deviceId,
            state: "disconnected",
            errorMessage: error?.localizedDescription
        )
        sessions.removeValue(forKey: deviceId)
    }

    func handleDidDisconnect(_ peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.identifier.uuidString
        emitState(
            deviceId: deviceId,
            state: "disconnected",
            errorMessage: error?.localizedDescription
        )
        sessions.removeValue(forKey: deviceId)
    }
}

// MARK: - FlutterStreamHandler

extension BleConnector: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        for payload in stateCache.values {
            events(payload)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        detachSink()
        return nil
    }
}
