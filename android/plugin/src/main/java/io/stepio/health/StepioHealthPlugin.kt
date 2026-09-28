package io.stepio.health

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.time.Instant

/**
 * Reads step counts from Health Connect for the step.io step reading test.
 *
 * GDScript sees this as Engine.get_singleton("StepioHealth"). The iOS
 * GDExtension exposes the same methods and signals, so game code does not
 * need to know which platform it is on.
 */
class StepioHealthPlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "StepioHealth"
        private const val REQUEST_PERMISSIONS = 7301
        private const val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"

        private val PERMISSIONS = setOf(HealthPermission.getReadPermission(StepsRecord::class))

        private val SIGNAL_PERMISSION_RESULT = SignalInfo(
            "permission_result", java.lang.Boolean::class.java, String::class.java
        )
        private val SIGNAL_STEPS_RESULT = SignalInfo(
            "steps_result",
            Integer::class.java,
            java.lang.Long::class.java,
            java.lang.Long::class.java,
            String::class.java
        )
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val permissionContract = PermissionController.createRequestPermissionResultContract()

    override fun getPluginName() = "StepioHealth"

    override fun getPluginSignals() = setOf(SIGNAL_PERMISSION_RESULT, SIGNAL_STEPS_RESULT)

    override fun onMainDestroy() {
        scope.cancel()
        super.onMainDestroy()
    }

    /** "available", "update_required" (Health Connect app missing or outdated) or "unsupported". */
    @UsedByGodot
    fun get_status(): String {
        val context = activity ?: return "unsupported"
        return when (HealthConnectClient.getSdkStatus(context, HEALTH_CONNECT_PACKAGE)) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
            else -> "unsupported"
        }
    }

    /** Emits permission_result(granted, message) without showing any UI. */
    @UsedByGodot
    fun check_permission() {
        val client = clientOrNull() ?: return emitPermission(false, "Health Connect is not available")
        scope.launch {
            try {
                val granted = client.permissionController.getGrantedPermissions().containsAll(PERMISSIONS)
                emitPermission(granted, if (granted) "Step access granted" else "Step access not granted yet")
            } catch (e: Exception) {
                Log.w(TAG, "check_permission failed", e)
                emitPermission(false, "Could not check permission: ${e.message}")
            }
        }
    }

    /** Shows the Health Connect permission screen, then emits permission_result(granted, message). */
    @UsedByGodot
    fun request_permission() {
        val act = activity ?: return emitPermission(false, "No activity")
        if (clientOrNull() == null) return emitPermission(false, "Health Connect is not available")
        act.runOnUiThread {
            try {
                val intent = permissionContract.createIntent(act, PERMISSIONS)
                act.startActivityForResult(intent, REQUEST_PERMISSIONS)
            } catch (e: Exception) {
                Log.w(TAG, "request_permission failed", e)
                emitPermission(false, "Could not open the permission screen: ${e.message}")
            }
        }
    }

    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onMainActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PERMISSIONS) return
        val granted = permissionContract.parseResult(resultCode, data).containsAll(PERMISSIONS)
        emitPermission(granted, if (granted) "Step access granted" else "Step access was denied")
    }

    /**
     * Counts steps between two Unix timestamps (seconds) and emits
     * steps_result(request_id, total, excluding_manual, error).
     *
     * total comes from Health Connect's aggregate, which removes overlap between
     * sources (phone and watch). excluding_manual sums the raw records minus the
     * ones the user typed in, so it can double count when several sources
     * recorded the same walk. Comparing the two is part of what this test checks.
     */
    @UsedByGodot
    fun query_steps(start_unix: Long, end_unix: Long, request_id: Int) {
        val client = clientOrNull() ?: return emitSteps(request_id, -1, -1, "Health Connect is not available")
        val range = TimeRangeFilter.between(Instant.ofEpochSecond(start_unix), Instant.ofEpochSecond(end_unix))
        scope.launch {
            try {
                val aggregate = client.aggregate(AggregateRequest(setOf(StepsRecord.COUNT_TOTAL), range))
                val total = aggregate[StepsRecord.COUNT_TOTAL] ?: 0L

                var excludingManual = 0L
                var pageToken: String? = null
                do {
                    val response = client.readRecords(
                        ReadRecordsRequest(StepsRecord::class, range, pageToken = pageToken)
                    )
                    for (record in response.records) {
                        if (record.metadata.recordingMethod != Metadata.RECORDING_METHOD_MANUAL_ENTRY) {
                            excludingManual += record.count
                        }
                    }
                    pageToken = response.pageToken
                } while (pageToken != null)

                emitSteps(request_id, total, excludingManual, "")
            } catch (e: SecurityException) {
                emitSteps(request_id, -1, -1, "No permission to read steps")
            } catch (e: Exception) {
                Log.w(TAG, "query_steps failed", e)
                emitSteps(request_id, -1, -1, e.message ?: e.javaClass.simpleName)
            }
        }
    }

    /** Opens Health Connect (or its Play Store page when it needs installing or updating). */
    @UsedByGodot
    fun open_settings() {
        val act: Activity = activity ?: return
        act.runOnUiThread {
            val intent = if (get_status() == "update_required") {
                Intent(Intent.ACTION_VIEW, Uri.parse(
                    "market://details?id=$HEALTH_CONNECT_PACKAGE&url=healthconnect%3A%2F%2Fonboarding"
                )).setPackage("com.android.vending")
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Health Connect is part of Android 14+, with its own settings screen.
                Intent("android.health.connect.action.HEALTH_HOME_SETTINGS")
            } else {
                Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
            }
            try {
                act.startActivity(intent)
            } catch (e: Exception) {
                Log.w(TAG, "open_settings failed", e)
            }
        }
    }

    private fun clientOrNull(): HealthConnectClient? {
        val context = activity ?: return null
        if (HealthConnectClient.getSdkStatus(context, HEALTH_CONNECT_PACKAGE) != HealthConnectClient.SDK_AVAILABLE) {
            return null
        }
        return HealthConnectClient.getOrCreate(context, HEALTH_CONNECT_PACKAGE)
    }

    private fun emitPermission(granted: Boolean, message: String) {
        runOnRenderThread { emitSignal(SIGNAL_PERMISSION_RESULT.name, granted, message) }
    }

    private fun emitSteps(requestId: Int, total: Long, excludingManual: Long, error: String) {
        runOnRenderThread { emitSignal(SIGNAL_STEPS_RESULT.name, requestId, total, excludingManual, error) }
    }
}
