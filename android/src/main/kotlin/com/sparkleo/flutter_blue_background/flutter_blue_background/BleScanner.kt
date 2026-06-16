package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel

/**
 * Owns the [BluetoothLeScanner] and translates a Dart [ScanConfig] map into
 * native [ScanFilter] / [ScanSettings], emitting discovered devices onto an
 * [EventChannel].
 *
 * Cross-platform filters that Android cannot do natively in a portable way
 * ([nameFilter] substring match and [rssiThreshold]) are applied client-side so
 * behaviour matches iOS.
 */
class BleScanner(private val context: Context) : EventChannel.StreamHandler {

    companion object {
        private const val TAG = "BleScanner"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var scanner: BluetoothLeScanner? = null
    private var activeCallback: ScanCallback? = null

    @Volatile
    var isScanning: Boolean = false
        private set

    // Client-side filters captured from the active config.
    private var nameFilter: String? = null
    private var skipUnnamedDevices: Boolean = false
    private var rssiThreshold: Int? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    @SuppressLint("MissingPermission")
    fun startScan(config: Map<String, Any?>): Boolean {
        if (!hasScanPermission()) {
            Log.w(TAG, "Missing BLUETOOTH_SCAN / location permission")
            return false
        }

        val adapter = bluetoothAdapter()
        if (adapter == null || !adapter.isEnabled) {
            Log.w(TAG, "Bluetooth adapter unavailable or disabled")
            return false
        }

        val leScanner = adapter.bluetoothLeScanner
        if (leScanner == null) {
            Log.w(TAG, "BluetoothLeScanner unavailable")
            return false
        }

        // Restart cleanly if already scanning.
        if (isScanning) {
            stopScan()
        }

        nameFilter = (config["nameFilter"] as? String)?.takeIf { it.isNotEmpty() }
        skipUnnamedDevices = config["skipUnnamedDevices"] as? Boolean ?: false
        rssiThreshold = (config["rssiThreshold"] as? Number)?.toInt()

        val filters = buildFilters(config)
        val settings = buildSettings(config)

        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                handleResult(result)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                results.forEach { handleResult(it) }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "Scan failed: $errorCode")
                isScanning = false
                mainHandler.post {
                    eventSink?.error(
                        "scan_failed",
                        "BLE scan failed with error code $errorCode",
                        null,
                    )
                }
            }
        }

        return try {
            leScanner.startScan(filters, settings, callback)
            scanner = leScanner
            activeCallback = callback
            isScanning = true
            Log.d(TAG, "Scan started (filters=${filters.size})")
            true
        } catch (e: Exception) {
            Log.e(TAG, "startScan threw: ${e.message}")
            false
        }
    }

    @SuppressLint("MissingPermission")
    fun stopScan(): Boolean {
        val leScanner = scanner
        val callback = activeCallback
        isScanning = false
        nameFilter = null
        skipUnnamedDevices = false
        rssiThreshold = null
        if (leScanner == null || callback == null) return true
        return try {
            if (hasScanPermission()) {
                leScanner.stopScan(callback)
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "stopScan threw: ${e.message}")
            false
        } finally {
            scanner = null
            activeCallback = null
        }
    }

    @SuppressLint("MissingPermission")
    private fun handleResult(result: ScanResult) {
        val record = result.scanRecord

        // Client-side name filter (substring, case-insensitive) for parity with iOS.
        val name = record?.deviceName ?: runCatching { result.device.name }.getOrNull()

        // Drop unnamed devices when requested.
        if (skipUnnamedDevices && name.isNullOrEmpty()) {
            return
        }

        nameFilter?.let { filter ->
            if (name == null || !name.contains(filter, ignoreCase = true)) {
                return
            }
        }

        // Client-side RSSI threshold.
        rssiThreshold?.let { threshold ->
            if (result.rssi < threshold) return
        }

        val serviceUuids = record?.serviceUuids?.map { it.uuid.toString() } ?: emptyList()

        val serviceData = HashMap<String, ByteArray>()
        record?.serviceData?.forEach { (uuid, bytes) ->
            serviceData[uuid.uuid.toString()] = bytes
        }

        val connectable: Boolean? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) result.isConnectable else null

        val payload: Map<String, Any?> = mapOf(
            "deviceId" to result.device.address,
            "name" to name,
            "rssi" to result.rssi,
            "txPowerLevel" to record?.txPowerLevel,
            "connectable" to connectable,
            "manufacturerData" to firstManufacturerData(result),
            "serviceUuids" to serviceUuids,
            "serviceData" to serviceData,
            "timestampMillis" to System.currentTimeMillis(),
        )

        mainHandler.post { eventSink?.success(payload) }
    }

    /**
     * Re-encodes the manufacturer-specific data with the 2-byte company id
     * prefix (little endian) so it matches the raw advertisement bytes that iOS
     * reports.
     */
    private fun firstManufacturerData(result: ScanResult): ByteArray? {
        val msd = result.scanRecord?.manufacturerSpecificData ?: return null
        if (msd.size() == 0) return null
        val companyId = msd.keyAt(0)
        val data = msd.valueAt(0) ?: return null
        val out = ByteArray(data.size + 2)
        out[0] = (companyId and 0xFF).toByte()
        out[1] = ((companyId shr 8) and 0xFF).toByte()
        System.arraycopy(data, 0, out, 2, data.size)
        return out
    }

    @Suppress("UNCHECKED_CAST")
    private fun buildFilters(config: Map<String, Any?>): List<ScanFilter> {
        val serviceUuids = config["serviceUuids"] as? List<String> ?: emptyList()
        if (serviceUuids.isEmpty()) return emptyList()
        return serviceUuids.mapNotNull { uuid ->
            runCatching {
                ScanFilter.Builder()
                    .setServiceUuid(ParcelUuid.fromString(uuid))
                    .build()
            }.getOrNull()
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun buildSettings(config: Map<String, Any?>): ScanSettings {
        val android = config["android"] as? Map<String, Any?> ?: emptyMap()
        val builder = ScanSettings.Builder()

        (android["scanMode"] as? Number)?.let { builder.setScanMode(it.toInt()) }
        (android["callbackType"] as? Number)?.let { builder.setCallbackType(it.toInt()) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            (android["matchMode"] as? Number)?.let { builder.setMatchMode(it.toInt()) }
            (android["numOfMatches"] as? Number)?.let {
                builder.setNumOfMatches(it.toInt())
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (android["legacy"] as? Boolean)?.let { builder.setLegacy(it) }
            (android["phy"] as? Number)?.let { builder.setPhy(it.toInt()) }
        }

        (config["reportDelayMillis"] as? Number)?.let {
            builder.setReportDelay(it.toLong())
        }

        return builder.build()
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    private fun hasScanPermission(): Boolean {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Manifest.permission.BLUETOOTH_SCAN
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }
        return ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    fun dispose() {
        stopScan()
        eventSink = null
    }
}
