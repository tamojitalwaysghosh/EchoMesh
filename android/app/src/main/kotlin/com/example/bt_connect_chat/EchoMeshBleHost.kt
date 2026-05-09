package com.example.bt_connect_chat

import android.Manifest
import android.content.pm.PackageManager
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import java.util.UUID

/**
 * BLE GATT server + advertiser so other EchoMesh installs (central role via flutter_blue_plus)
 * can discover, connect, write RX, and receive TX notifications.
 */
class EchoMeshBleHost(private val context: android.content.Context) {

    companion object {
        private const val TAG = "EchoMeshBleHost"
        val SERVICE_UUID: UUID = UUID.fromString("A1B2C3D4-E5F6-4790-ABCD-EF1234567890")
        val RX_CHAR_UUID: UUID = UUID.fromString("A1B2C3D4-E5F6-4790-ABCD-EF1234567891")
        val TX_CHAR_UUID: UUID = UUID.fromString("A1B2C3D4-E5F6-4790-ABCD-EF1234567892")
        private val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    var onPayloadReceived: ((String) -> Unit)? = null
    var onConnectionEvent: ((String) -> Unit)? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var bluetoothManager: BluetoothManager? = null
    private var advertiser: android.bluetooth.le.BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var gattServer: BluetoothGattServer? = null
    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var notifyTarget: BluetoothDevice? = null

    fun start(displayName: String): Boolean {
        return try {
            stop()
            if (!hasBlePermissions()) {
                Log.w(TAG, "BLE permissions missing")
                return false
            }
            bluetoothManager = context.getSystemService(android.content.Context.BLUETOOTH_SERVICE) as BluetoothManager
            val adapter = bluetoothManager?.adapter ?: return false
            if (!adapter.isEnabled) return false

            advertiser = adapter.bluetoothLeAdvertiser ?: return false

            val safeName = displayName.trim().ifEmpty { "EchoMesh" }.take(22)
            try {
                @Suppress("DEPRECATION")
                adapter.name = "EM-$safeName"
            } catch (e: SecurityException) {
                Log.w(TAG, "Could not set adapter name", e)
            }

            if (!openGattServer()) return false

            mainHandler.postDelayed({
                startAdvertisingInternal()
            }, 400)
            true
        } catch (e: Exception) {
            Log.e(TAG, "start()", e)
            false
        }
    }

    private fun startAdvertisingInternal() {
        val advertiser = this.advertiser ?: return

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                Log.i(TAG, "Advertising started")
            }

            override fun onStartFailure(errorCode: Int) {
                Log.e(TAG, "Advertising failed: $errorCode")
            }
        }
        try {
            advertiser.startAdvertising(settings, data, advertiseCallback!!)
        } catch (e: Exception) {
            Log.e(TAG, "startAdvertising", e)
        }
    }

    fun stop() {
        mainHandler.removeCallbacksAndMessages(null)
        try {
            advertiseCallback?.let { advertiser?.stopAdvertising(it) }
        } catch (_: Exception) {
        }
        advertiseCallback = null
        advertiser = null

        try {
            gattServer?.close()
        } catch (_: Exception) {
        }
        gattServer = null
        txCharacteristic = null
        notifyTarget = null
    }

    private fun openGattServer(): Boolean {
        val manager = bluetoothManager ?: return false
        val rx = BluetoothGattCharacteristic(
            RX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
        )
        val tx = BluetoothGattCharacteristic(
            TX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ,
        )
        val cccd = BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE,
        )
        tx.addDescriptor(cccd)

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        service.addCharacteristic(rx)
        service.addCharacteristic(tx)

        val callback = object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                if (newState == BluetoothGatt.STATE_CONNECTED) {
                    mainHandler.post {
                        onConnectionEvent?.invoke("evt|conn|CONNECTED|${device.address}")
                    }
                } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                    mainHandler.post {
                        onConnectionEvent?.invoke("evt|conn|DISCONNECTED|${device.address}")
                    }
                }
                if (newState != BluetoothGatt.STATE_CONNECTED) {
                    if (notifyTarget?.address == device.address) notifyTarget = null
                }
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray,
            ) {
                if (characteristic.uuid == RX_CHAR_UUID) {
                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_SUCCESS,
                            offset,
                            null,
                        )
                    }
                    val text = value.toString(Charsets.UTF_8)
                    if (text.isNotEmpty()) {
                        mainHandler.post {
                            onPayloadReceived?.invoke("${device.address}|$text")
                        }
                    }
                } else {
                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_FAILURE,
                            offset,
                            null,
                        )
                    }
                }
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray,
            ) {
                if (descriptor.uuid == CCCD_UUID) {
                    val enabled = value.isNotEmpty() && value[0].toInt() != 0
                    if (enabled && descriptor.characteristic.uuid == TX_CHAR_UUID) {
                        notifyTarget = device
                    }
                }
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }
            }

            override fun onDescriptorReadRequest(
                device: BluetoothDevice,
                requestId: Int,
                offset: Int,
                descriptor: BluetoothGattDescriptor,
            ) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null)
            }
        }

        gattServer = manager.openGattServer(context, callback)
        val ok = gattServer?.addService(service) == true
        txCharacteristic = tx
        return ok
    }

    fun notifySubscribers(jsonPayload: String) {
        val server = gattServer ?: return
        val ch = txCharacteristic ?: return
        val device = notifyTarget ?: return
        ch.value = jsonPayload.toByteArray(Charsets.UTF_8)
        server.notifyCharacteristicChanged(device, ch, false)
    }

    private fun hasBlePermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val connect = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        val scan = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        val advertise = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED
        return connect && scan && advertise
    }
}
