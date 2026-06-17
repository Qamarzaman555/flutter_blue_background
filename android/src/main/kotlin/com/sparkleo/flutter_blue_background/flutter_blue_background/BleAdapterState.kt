package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Reads and maps the system Bluetooth adapter state to the cross-platform
 * string values consumed by Dart [BleAdapterState].
 */
object BleAdapterState {

    fun getState(context: Context): String {
        if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            return "unsupported"
        }

        if (!hasBluetoothPermission(context)) {
            return "unauthorized"
        }

        val adapter = bluetoothAdapter(context) ?: return "unsupported"

        return when (adapter.state) {
            BluetoothAdapter.STATE_ON -> "on"
            BluetoothAdapter.STATE_TURNING_ON -> "turningOn"
            BluetoothAdapter.STATE_OFF -> "off"
            BluetoothAdapter.STATE_TURNING_OFF -> "turningOff"
            else -> "unknown"
        }
    }

    fun isReady(context: Context): Boolean = getState(context) == "on"

    private fun bluetoothAdapter(context: Context): BluetoothAdapter? {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    private fun hasBluetoothPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_CONNECT,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }
}
