package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Owns active GATT connections inside [FlutterBlueBackgroundService].
 *
 * Connection state is mirrored to Flutter through [ConnectionStateDispatcher].
 */
class BleConnector(private val context: Context) {

    companion object {
        /** GAP service and Services Changed characteristic. */
        private val GAP_SERVICE_UUID = java.util.UUID.fromString(
            "00001801-0000-1000-8000-00805f9b34fb",
        )
        private val SERVICES_CHANGED_UUID = java.util.UUID.fromString(
            "00002a05-0000-1000-8000-00805f9b34fb",
        )
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val sessions = ConcurrentHashMap<String, DeviceSession>()

    private data class DeviceSession(
        val deviceId: String,
        var gatt: BluetoothGatt? = null,
        var config: Map<String, Any?>? = null,
        var mtu: Int = 23,
        var connectTimestamp: Long = 0,
        var timeoutRunnable: Runnable? = null,
        var pendingDiscoverLatch: CountDownLatch? = null,
        var pendingDiscoverResult: List<Map<String, Any?>>? = null,
        var pendingMtuLatch: CountDownLatch? = null,
        var pendingMtuResult: Int? = null,
    )

    @SuppressLint("MissingPermission")
    fun connect(deviceId: String, config: Map<String, Any?>): Boolean {
        if (!BlePermissions.hasConnectPermission(context)) {
            FbbLog.warning("Missing BLUETOOTH_CONNECT permission")
            emitState(deviceId, "disconnected", errorMessage = "Missing Bluetooth permission")
            return false
        }

        if (!BleAdapterState.isReady(context)) {
            FbbLog.warning("Bluetooth adapter not ready")
            emitState(deviceId, "disconnected", errorMessage = "Bluetooth adapter is not ready")
            return false
        }

        val adapter = bluetoothAdapter() ?: run {
            emitState(deviceId, "disconnected", errorMessage = "Bluetooth adapter unavailable")
            return false
        }

        val autoConnect = config["autoConnect"] as? Boolean ?: false
        val existing = sessions[deviceId]
        if (existing?.gatt != null &&
            ConnectionStateDispatcher.getState(deviceId) == "connected"
        ) {
            FbbLog.debug("Already connected to $deviceId")
            return true
        }

        // Tear down any in-flight connection attempt first.
        disconnectInternal(deviceId, androidDelayMillis = 0, waitMs = 0)

        val android = config["android"] as? Map<String, Any?> ?: emptyMap()
        val transport = (android["transport"] as? Number)?.toInt()
            ?: BluetoothDevice.TRANSPORT_LE
        val phy = (android["phy"] as? Number)?.toInt()
            ?: BluetoothDevice.PHY_LE_1M_MASK

        val session = DeviceSession(deviceId = deviceId, config = config)
        sessions[deviceId] = session

        emitState(deviceId, "connecting", mtu = session.mtu)
        FbbLog.debug("connect: $deviceId autoConnect=$autoConnect transport=$transport")

        val device = runCatching { adapter.getRemoteDevice(deviceId) }.getOrNull()
        if (device == null) {
            emitState(deviceId, "disconnected", errorMessage = "Invalid device id")
            sessions.remove(deviceId)
            return false
        }

        val callback = createGattCallback(deviceId)
        val gatt = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                device.connectGatt(context, autoConnect, callback, transport, phy)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(context, autoConnect, callback, transport)
            } else {
                device.connectGatt(context, autoConnect, callback)
            }
        } catch (e: Exception) {
            FbbLog.error("connectGatt failed: ${e.message}")
            emitState(deviceId, "disconnected", errorMessage = e.message)
            sessions.remove(deviceId)
            return false
        }

        session.gatt = gatt
        session.connectTimestamp = System.currentTimeMillis()

        if (!autoConnect) {
            val timeoutMillis = (config["timeoutMillis"] as? Number)?.toLong()
                ?: 35_000L
            val runnable = Runnable {
                if (ConnectionStateDispatcher.getState(deviceId) != "connected") {
                    FbbLog.warning("Connection timeout for $deviceId")
                    disconnectInternal(deviceId, androidDelayMillis = 0, waitMs = 0)
                    emitState(
                        deviceId,
                        "disconnected",
                        errorMessage = "Connection timeout",
                    )
                }
            }
            session.timeoutRunnable = runnable
            mainHandler.postDelayed(runnable, timeoutMillis)
        }

        return true
    }

    @SuppressLint("MissingPermission")
    fun disconnect(deviceId: String, config: Map<String, Any?>): Boolean {
        FbbLog.debug("disconnect: $deviceId")
        val androidDelay = (config["androidDelayMillis"] as? Number)?.toLong() ?: 2000L
        val waitMs = (config["timeoutMillis"] as? Number)?.toLong() ?: 35_000L
        disconnectInternal(deviceId, androidDelay, waitMs)
        return true
    }

    fun getConnectionState(deviceId: String): String =
        ConnectionStateDispatcher.getState(deviceId)

    fun getConnectedDeviceIds(): List<String> =
        ConnectionStateDispatcher.getConnectedDeviceIds()

    @SuppressLint("MissingPermission")
    fun requestMtu(deviceId: String, mtu: Int): Int {
        val session = sessions[deviceId] ?: return 23
        val gatt = session.gatt ?: return session.mtu
        if (!BlePermissions.hasConnectPermission(context)) return session.mtu

        val latch = CountDownLatch(1)
        session.pendingMtuLatch = latch
        session.pendingMtuResult = null

        val started = gatt.requestMtu(mtu.coerceIn(23, 517))
        if (!started) {
            session.pendingMtuLatch = null
            return session.mtu
        }

        latch.await(15, TimeUnit.SECONDS)
        session.pendingMtuLatch = null
        return session.pendingMtuResult ?: session.mtu
    }

    @SuppressLint("MissingPermission")
    fun requestConnectionPriority(deviceId: String, priority: Int): Boolean {
        val session = sessions[deviceId] ?: return false
        val gatt = session.gatt ?: return false
        if (!BlePermissions.hasConnectPermission(context)) return false

        val nativePriority = when (priority) {
            1 -> BluetoothGatt.CONNECTION_PRIORITY_HIGH
            2 -> BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER
            else -> BluetoothGatt.CONNECTION_PRIORITY_BALANCED
        }
        return gatt.requestConnectionPriority(nativePriority)
    }

    @SuppressLint("MissingPermission")
    fun discoverServices(
        deviceId: String,
        timeoutMillis: Long,
        subscribeToServicesChanged: Boolean,
    ): List<Map<String, Any?>>? {
        val session = sessions[deviceId] ?: return null
        val gatt = session.gatt ?: return null
        if (ConnectionStateDispatcher.getState(deviceId) != "connected") return null
        if (!BlePermissions.hasConnectPermission(context)) return null

        session.config = (session.config ?: emptyMap()).toMutableMap().apply {
            put("subscribeToServicesChanged", subscribeToServicesChanged)
        }

        val latch = CountDownLatch(1)
        session.pendingDiscoverLatch = latch
        session.pendingDiscoverResult = null

        if (!gatt.discoverServices()) {
            session.pendingDiscoverLatch = null
            return null
        }

        latch.await(timeoutMillis.coerceAtLeast(1000), TimeUnit.MILLISECONDS)
        session.pendingDiscoverLatch = null
        return session.pendingDiscoverResult
    }

    fun dispose() {
        forceDisconnectAll(reason = null)
    }

    /**
     * Called when the system Bluetooth adapter turns off. Emits disconnected
     * events immediately so Flutter UI stays in sync (unlike async GATT teardown).
     */
    fun onBluetoothAdapterOff() {
        forceDisconnectAll(reason = "Bluetooth turned off")
    }

    @SuppressLint("MissingPermission")
    private fun forceDisconnectAll(reason: String?) {
        for (deviceId in sessions.keys.toList()) {
            val session = sessions.remove(deviceId) ?: continue
            session.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
            session.gatt?.let { gatt ->
                runCatching {
                    if (BlePermissions.hasConnectPermission(context)) {
                        gatt.disconnect()
                    }
                    gatt.close()
                }
            }
            emitState(
                deviceId,
                "disconnected",
                mtu = session.mtu,
                errorMessage = reason,
            )
        }
        sessions.clear()
    }

    @SuppressLint("MissingPermission")
    private fun disconnectInternal(
        deviceId: String,
        androidDelayMillis: Long,
        waitMs: Long,
    ) {
        val session = sessions[deviceId] ?: return
        session.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        session.timeoutRunnable = null

        val gatt = session.gatt
        if (gatt == null) {
            emitState(deviceId, "disconnected")
            sessions.remove(deviceId)
            return
        }

        val elapsed = System.currentTimeMillis() - session.connectTimestamp
        val delay = (androidDelayMillis - elapsed).coerceAtLeast(0)
        mainHandler.postDelayed({
            emitState(deviceId, "disconnecting", mtu = session.mtu)
            if (BlePermissions.hasConnectPermission(context)) {
                runCatching { gatt.disconnect() }
                runCatching { gatt.close() }
            }
            session.gatt = null
            emitState(deviceId, "disconnected", mtu = session.mtu)
            sessions.remove(deviceId)
            ConnectionStateDispatcher.remove(deviceId)
        }, if (waitMs <= 0) 0 else delay.coerceAtMost(waitMs))
    }

    private fun createGattCallback(deviceId: String): BluetoothGattCallback {
        return object : BluetoothGattCallback() {
            override fun onConnectionStateChange(
                gatt: BluetoothGatt,
                status: Int,
                newState: Int,
            ) {
                val session = sessions[deviceId] ?: return
                FbbLog.debug(
                    "onConnectionStateChange: $deviceId state=$newState status=$status",
                )
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        session.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                        session.timeoutRunnable = null
                        session.gatt = gatt
                        emitState(deviceId, "connected", mtu = session.mtu)

                        val config = session.config ?: emptyMap()
                        val android = config["android"] as? Map<String, Any?> ?: emptyMap()

                        if (!BlePermissions.hasConnectPermission(context)) return

                        val priority = (android["connectionPriority"] as? Number)?.toInt() ?: 0
                        requestConnectionPriority(deviceId, priority)

                        val autoConnect = config["autoConnect"] as? Boolean ?: false
                        val mtu = (android["mtu"] as? Number)?.toInt()
                        if (!autoConnect && mtu != null) {
                            gatt.requestMtu(mtu.coerceIn(23, 517))
                        } else if (config["discoverServicesOnConnect"] as? Boolean != false) {
                            gatt.discoverServices()
                        }
                    }

                    BluetoothProfile.STATE_DISCONNECTED -> {
                        session.timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                        session.timeoutRunnable = null
                        runCatching { gatt.close() }
                        session.gatt = null
                        val message = if (status != BluetoothGatt.GATT_SUCCESS) {
                            "GATT status $status"
                        } else {
                            null
                        }
                        emitState(
                            deviceId,
                            "disconnected",
                            mtu = session.mtu,
                            errorMessage = message,
                            errorCode = if (status != BluetoothGatt.GATT_SUCCESS) status else null,
                        )
                        sessions.remove(deviceId)
                    }
                }
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                val session = sessions[deviceId] ?: return
                FbbLog.debug("onMtuChanged: $deviceId mtu=$mtu status=$status")
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    session.mtu = mtu
                    emitState(deviceId, "connected", mtu = mtu)
                }
                session.pendingMtuResult = session.mtu
                session.pendingMtuLatch?.countDown()

                val config = session.config ?: return
                if (config["discoverServicesOnConnect"] as? Boolean != false &&
                    session.pendingDiscoverLatch == null
                ) {
                    gatt.discoverServices()
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                val session = sessions[deviceId] ?: return
                val count = if (status == BluetoothGatt.GATT_SUCCESS) gatt.services.size else 0
                FbbLog.debug(
                    "onServicesDiscovered: $deviceId count=$count status=$status",
                )
                val services = if (status == BluetoothGatt.GATT_SUCCESS) {
                    mapServices(gatt)
                } else {
                    emptyList()
                }

                session.pendingDiscoverResult = services
                session.pendingDiscoverLatch?.countDown()

                val subscribe = session.config?.get("subscribeToServicesChanged") as? Boolean
                    ?: true
                if (subscribe) {
                    subscribeServicesChanged(gatt)
                }
            }

            override fun onServiceChanged(gatt: BluetoothGatt) {
                FbbLog.info("onServiceChanged: ${gatt.device.address}")
                if (!BlePermissions.hasConnectPermission(context)) return
                gatt.discoverServices()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun subscribeServicesChanged(gatt: BluetoothGatt) {
        val service = gatt.getService(GAP_SERVICE_UUID) ?: return
        val characteristic = service.getCharacteristic(SERVICES_CHANGED_UUID) ?: return
        gatt.setCharacteristicNotification(characteristic, true)
        val descriptor = characteristic.getDescriptor(
            java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
        ) ?: return
        descriptor.value = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
        gatt.writeDescriptor(descriptor)
    }

    private fun mapServices(gatt: BluetoothGatt): List<Map<String, Any?>> {
        val filterUuids = (sessions[gatt.device.address]?.config?.get("serviceUuids")
            as? List<*>)?.mapNotNull { it?.toString() }?.toSet()

        return gatt.services.mapNotNull { service ->
            val uuid = service.uuid.toString()
            if (filterUuids != null && filterUuids.isNotEmpty() && uuid !in filterUuids) {
                return@mapNotNull null
            }
            mapOf(
                "uuid" to uuid,
                "characteristics" to service.characteristics.map { mapCharacteristic(it) },
            )
        }
    }

    private fun mapCharacteristic(
        characteristic: BluetoothGattCharacteristic,
    ): Map<String, Any?> {
        val props = mutableListOf<String>()
        val p = characteristic.properties
        if (p and BluetoothGattCharacteristic.PROPERTY_READ != 0) props.add("read")
        if (p and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) props.add("write")
        if (p and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) {
            props.add("writeWithoutResponse")
        }
        if (p and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) props.add("notify")
        if (p and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) props.add("indicate")
        return mapOf(
            "uuid" to characteristic.uuid.toString(),
            "properties" to props,
        )
    }

    private fun emitState(
        deviceId: String,
        state: String,
        mtu: Int? = null,
        errorMessage: String? = null,
        errorCode: Int? = null,
    ) {
        val event = mutableMapOf<String, Any?>(
            "deviceId" to deviceId,
            "state" to state,
        )
        mtu?.let { event["mtu"] = it }
        errorMessage?.let { event["errorMessage"] = it }
        errorCode?.let { event["errorCode"] = it }
        ConnectionStateDispatcher.emit(event)
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }
}

/** Lets the plugin invoke GATT ops on the service-owned connector. */
object BleConnectorHolder {
    @Volatile
    var connector: BleConnector? = null
}
