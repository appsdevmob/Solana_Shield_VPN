package com.hiddify.hiddify

import android.util.Log
import com.hiddify.hiddify.bg.BoxService
//import com.hiddify.hiddify.bg.BoxService.Companion.workingDir
import com.hiddify.hiddify.constant.Status
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import com.hiddify.core.libbox.Libbox
import com.hiddify.core.mobile.Mobile
import com.hiddify.core.mobile.SetupOptions
import com.hiddify.hiddify.bg.Bugs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MethodHandler(private val scope: CoroutineScope) : FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "com.hiddify.app/method"

        enum class Trigger(val method: String) {
            Setup("setup"),
            Start("start"),
            Stop("stop"),
            Restart("restart"),
            AddGrpcClientPublicKey("add_grpc_client_public_key"),
            GetGrpcServerPublicKey("get_grpc_server_public_key"),

        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            channelName,
        )
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Trigger.AddGrpcClientPublicKey.method -> {
                GlobalScope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        val clientPub = args["clientPublicKey"] as ByteArray
//                        Mobile.addGrpcClientPublicKey(clientPub)
                        Settings.grpcFlutterPublicKey = clientPub
                        success("")

                    }
                }
            }

            Trigger.GetGrpcServerPublicKey.method -> {
                GlobalScope.launch {
                    result.runCatching {
                        result.success(Mobile.getServerPublicKey())
                    }
                }
            }

            Trigger.Setup.method -> {
                GlobalScope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        Settings.baseDir = args["baseDir"] as String
                        Settings.workingDir = args["workingDir"] as String
                        Settings.tempDir = args["tempDir"] as String
                        Settings.debugMode = args["debug"] as Boolean? ?: false
                        val mode = args["mode"] as Int
                        val grpcPort = args["grpcPort"] as Int
                        Log.d("debugmode","${Settings.debugMode}")
                        runCatching {
                            Mobile.setup(
                                SetupOptions().also {
                                    it.basePath = Settings.baseDir
                                    it.workingDir = Settings.workingDir
                                    it.tempDir = Settings.tempDir
                                    it.fixAndroidStack = Bugs.fixAndroidStack
                                    it.mode=mode.toLong()
                                    it.listen= "127.0.0.1:" + grpcPort
                                    it.secret=""
                                    it.debug = Settings.debugMode
                                },null)

//                            Libbox.setup(Settings.baseDir, Settings.workingDir, Settings.tempDir, false)
                            Libbox.redirectStderr(File(Settings.workingDir, "stderr2.log").path)

                            success("")
                        }.onFailure {
                            error(it)
                        }

                    }
                }
            }


            Trigger.Start.method -> {
                scope.launch {
                    val args = call.arguments as Map<*, *>
                    Settings.activeConfigPath = args["path"] as String? ?: ""
                    Settings.activeProfileName = args["name"] as String? ?: ""
                    Settings.debugMode = args["debug"] as Boolean? ?: false
                    Settings.grpcServiceModePort = args["grpcPort"] as Int

                    val mainActivity = MainActivity.instance
                    Settings.startCoreAfterStartingService = false

                    // Check if already started
                    val started = mainActivity.serviceStatus.value == Status.Started
                    if (started) {
                        result.success(true)
                        return@launch
                    }

                    // Step 1: Request notification permission (suspends until user responds)
                    Log.d(TAG, "Start: requesting notification permission")
                    val notifGranted = withContext(Dispatchers.Main) {
                        mainActivity.requestNotificationPermission()
                    }
                    if (!notifGranted) {
                        Log.w(TAG, "Start: notification permission denied")
                        result.success(false)
                        return@launch
                    }

                    // Step 2: Request VPN permission (suspends until user responds)
                    Log.d(TAG, "Start: requesting VPN permission")
                    val vpnGranted = withContext(Dispatchers.Main) {
                        mainActivity.requestVpnPermission()
                    }
                    if (!vpnGranted) {
                        Log.w(TAG, "Start: VPN permission denied")
                        mainActivity.onServiceAlert(
                            com.hiddify.hiddify.constant.Alert.RequestVPNPermission, null
                        )
                        result.success(false)
                        return@launch
                    }

                    Log.d(TAG, "Start: all permissions granted, starting foreground service")

                    // Step 3: Set up observer THEN start service
                    var isCompleted = false
                    val observer = androidx.lifecycle.Observer<Status> { status ->
                        if (status == Status.Started || status == Status.Stopped) {
                            if (!isCompleted) {
                                isCompleted = true
                                Log.d(TAG, "Start: service status changed to $status")
                                result.success(status == Status.Started)
                            }
                        }
                    }
                    
                    withContext(Dispatchers.Main) {
                        mainActivity.serviceStatus.observeForever(observer)
                    }

                    // Start the foreground service (permissions already verified)
                    mainActivity.startForegroundServiceDirect()

                    // Cleanup observer after timeout (30s to account for service startup)
                    delay(30000)
                    withContext(Dispatchers.Main) {
                        mainActivity.serviceStatus.removeObserver(observer)
                    }
                    if (!isCompleted) {
                        isCompleted = true
                        Log.w(TAG, "Start: timed out waiting for service status")
                        result.success(false)
                    }
                }
            }

            Trigger.Stop.method -> {
                scope.launch {
                    result.runCatching {
                        val mainActivity = MainActivity.instance
                        val started = mainActivity.serviceStatus.value == Status.Started
                        if (!started) {
                            Log.w(TAG, "service is not running")
                            //    return@launch success(true)
                        }
                        BoxService.stop()
                        success(true)
                    }
                }
            }

//            Trigger.Restart.method -> {
//                scope.launch(Dispatchers.IO) {
//                    result.runCatching {
//                        val args = call.arguments as Map<*, *>
//                        Settings.activeConfigPath = args["path"] as String? ?: ""
//                        Settings.activeProfileName = args["name"] as String? ?: ""
//                        val mainActivity = MainActivity.instance
//                        val started = mainActivity.serviceStatus.value == Status.Started
//                        if (!started) return@launch success(true)
//                        val restart = Settings.rebuildServiceMode()
//                        if (restart) {
//                            mainActivity.reconnect()
//                            BoxService.stop()
//                            delay(1000L)
//                            mainActivity.startService()
//                            return@launch success(true)
//                        }
//                        runCatching {
//                            Libbox.newStandaloneCommandClient().serviceReload()
//                            success(true)
//                        }.onFailure {
//                            error(it)
//                        }
//                    }
//                }
//            }

            else -> result.notImplemented()
        }
    }
}