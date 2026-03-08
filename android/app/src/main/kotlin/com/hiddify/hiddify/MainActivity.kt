package com.hiddify.hiddify

import android.annotation.SuppressLint
import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.lifecycleScope
import com.hiddify.hiddify.bg.ServiceConnection
import com.hiddify.hiddify.bg.ServiceNotification
import com.hiddify.hiddify.constant.Alert
import com.hiddify.hiddify.constant.ServiceMode
import com.hiddify.hiddify.constant.Status
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.util.LinkedList
import kotlin.coroutines.resume


class MainActivity : FlutterFragmentActivity(), ServiceConnection.Callback {
    companion object {
        private const val TAG = "ANDROID/MyActivity"
        lateinit var instance: MainActivity

        const val VPN_PERMISSION_REQUEST_CODE = 1001
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1010
    }

    private val connection = ServiceConnection(this, this)

    val logList = LinkedList<String>()
    var logCallback: ((Boolean) -> Unit)? = null
    val serviceStatus = MutableLiveData(Status.Stopped)
    val serviceAlerts = MutableLiveData<ServiceEvent?>(null)

    // Continuation for VPN permission dialog result
    private var vpnPermissionContinuation: kotlin.coroutines.Continuation<Boolean>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        reconnect()
        flutterEngine.plugins.add(MethodHandler(lifecycleScope))
        flutterEngine.plugins.add(PlatformSettingsHandler())
        flutterEngine.plugins.add(EventHandler())
        flutterEngine.plugins.add(LogHandler())
    }

    fun reconnect() {
        connection.reconnect()
    }

    /**
     * Public suspend function to request VPN permission.
     * Can be called from MethodHandler BEFORE starting the service.
     * MUST be called from the Main dispatcher.
     * Returns true if VPN permission is granted, false otherwise.
     */
    suspend fun requestVpnPermission(): Boolean {
        Log.d(TAG, "requestVpnPermission() called")
        if (Settings.serviceMode != ServiceMode.VPN) {
            Log.d(TAG, "Not in VPN mode, skipping VPN permission check")
            return true
        }
        return prepareAndWait()
    }

    /**
     * Public suspend function to request notification permission.
     * Returns true if notification permission is granted (or not needed).
     */
    @SuppressLint("NewApi")
    suspend fun requestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true // Not needed on older Android
        }
        if (ServiceNotification.checkPermission()) {
            return true // Already granted
        }
        Log.d(TAG, "Requesting notification permission")
        return suspendCancellableCoroutine { cont ->
            notificationPermissionContinuation = cont
            cont.invokeOnCancellation { notificationPermissionContinuation = null }
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    // Continuation for notification permission
    private var notificationPermissionContinuation: kotlin.coroutines.Continuation<Boolean>? = null

    @SuppressLint("NewApi")
    fun startService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !ServiceNotification.checkPermission()) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            return
        }
        startService0()
    }

    private fun startService0() {
        lifecycleScope.launch(Dispatchers.IO) {
            if (Settings.rebuildServiceMode()) {
                connection.reconnect()
            }
            if (Settings.serviceMode == ServiceMode.VPN) {
                val permissionGranted = prepareAndWait()
                if (!permissionGranted) {
                    Log.w(TAG, "VPN permission denied or error, posting Stopped status")
                    onServiceAlert(Alert.RequestVPNPermission, null)
                    serviceStatus.postValue(Status.Stopped)
                    return@launch
                }
            }
            val intent = Intent(Application.application, Settings.serviceClass())
            withContext(Dispatchers.Main) {
                ContextCompat.startForegroundService(this@MainActivity, intent)
            }
            Settings.startedByUser = true
        }
    }

    /**
     * Start the foreground service directly, AFTER permissions have been verified.
     * This is called from MethodHandler after VPN permission is confirmed.
     */
    fun startForegroundServiceDirect() {
        lifecycleScope.launch(Dispatchers.IO) {
            if (Settings.rebuildServiceMode()) {
                connection.reconnect()
            }
            val intent = Intent(Application.application, Settings.serviceClass())
            withContext(Dispatchers.Main) {
                Log.d(TAG, "Starting foreground service directly (permissions already verified)")
                ContextCompat.startForegroundService(this@MainActivity, intent)
            }
            Settings.startedByUser = true
        }
    }

    /**
     * Checks VPN permission and, if needed, shows the system VPN dialog.
     * Suspends the coroutine until the user responds.
     * Returns true if permission is granted, false if denied or error.
     */
    private suspend fun prepareAndWait(): Boolean = withContext(Dispatchers.Main) {
        try {
            Log.d(TAG, "prepareAndWait: calling VpnService.prepare()")
            val intent = VpnService.prepare(this@MainActivity)
            if (intent != null) {
                // Need to request permission — suspend until user responds
                Log.d(TAG, "VPN permission needed, showing system dialog (intent=$intent)")
                val granted = suspendCancellableCoroutine<Boolean> { cont ->
                    vpnPermissionContinuation = cont
                    cont.invokeOnCancellation {
                        Log.d(TAG, "VPN permission coroutine cancelled")
                        vpnPermissionContinuation = null
                    }
                    try {
                        prepareLauncher.launch(intent)
                        Log.d(TAG, "prepareLauncher.launch() called successfully")
                    } catch (e: Exception) {
                        Log.e(TAG, "prepareLauncher.launch() failed: ${e.message}", e)
                        vpnPermissionContinuation = null
                        cont.resume(false)
                    }
                }
                Log.d(TAG, "VPN permission dialog result: granted=$granted")
                granted
            } else {
                // Permission already granted
                Log.d(TAG, "VPN permission already granted (prepare returned null)")
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "VPN prepare() exception: ${e.message}", e)
            false
        }
    }

    private val notificationPermissionLauncher =
        registerForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { isGranted ->
            Log.d(TAG, "Notification permission result: granted=$isGranted")
            // Resume notification permission continuation if exists
            val notifCont = notificationPermissionContinuation
            notificationPermissionContinuation = null
            if (notifCont != null) {
                notifCont.resume(isGranted || !Settings.dynamicNotification)
            } else {
                // Legacy path: called from startService()
                if (Settings.dynamicNotification && !isGranted) {
                    onServiceAlert(Alert.RequestNotificationPermission, null)
                } else {
                    startService0()
                }
            }
        }

    private val prepareLauncher =
        registerForActivityResult(
            ActivityResultContracts.StartActivityForResult(),
        ) { result ->
            val granted = result.resultCode == RESULT_OK
            Log.d(TAG, "VPN permission dialog returned: resultCode=${result.resultCode}, granted=$granted")
            val cont = vpnPermissionContinuation
            vpnPermissionContinuation = null
            if (cont != null) {
                // Resume the suspended coroutine with the result
                cont.resume(granted)
            } else {
                Log.w(TAG, "prepareLauncher: no continuation found, using fallback")
                // Fallback: if no continuation (shouldn't happen), use old behavior
                if (granted) {
                    startService0()
                } else {
                    onServiceAlert(Alert.RequestVPNPermission, null)
                }
            }
        }

    override fun onServiceStatusChanged(status: Status) {
        serviceStatus.postValue(status)
    }

    override fun onServiceAlert(type: Alert, message: String?) {
        Log.d(TAG, "onServiceAlert: type=$type, message=$message")
        serviceAlerts.postValue(ServiceEvent(Status.Stopped, type, message))
    }

    override fun onDestroy() {
        connection.disconnect()
        super.onDestroy()
    }

    @SuppressLint("NewApi")
    private fun grantNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startService()
            } else onServiceAlert(Alert.RequestNotificationPermission, null)
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            if (resultCode == RESULT_OK) startService()
            else onServiceAlert(Alert.RequestVPNPermission, null)
        } else if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            if (resultCode == RESULT_OK) startService()
            else onServiceAlert(Alert.RequestNotificationPermission, null)
        }
    }
}
