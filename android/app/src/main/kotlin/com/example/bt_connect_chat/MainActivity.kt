package com.example.bt_connect_chat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val host = EchoMeshBleHost(this)
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        host.onPayloadReceived = { json ->
            runOnUiThread {
                eventSink?.success(json)
            }
        }
        host.onConnectionEvent = { evt ->
            runOnUiThread {
                eventSink?.success(evt)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "echomesh/ble_host").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val name = call.argument<String>("name") ?: "EchoMesh"
                    result.success(host.start(name))
                }
                "stop" -> {
                    host.stop()
                    result.success(true)
                }
                "notify" -> {
                    val payload = call.argument<String>("payload") ?: ""
                    host.notifySubscribers(payload)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "echomesh/ble_host_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    override fun onDestroy() {
        host.stop()
        super.onDestroy()
    }
}
