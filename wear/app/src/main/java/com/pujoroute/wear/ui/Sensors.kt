package com.pujoroute.wear.ui

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Looper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner

/** Snapshot of the watch's location state for a screen. */
data class LocationUi(
    val hasPermission: Boolean,
    val location: Location?,
    val providerAvailable: Boolean = true,
    val requestPermission: () -> Unit = {},
)

private fun hasLocationPermission(ctx: Context) =
    ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

/**
 * Foreground-only location via the platform LocationManager (no Google Play Services).
 * Updates run only while the calling screen is composed AND the activity is resumed.
 */
@SuppressLint("MissingPermission")
@Composable
fun rememberWatchLocation(): LocationUi {
    val ctx = LocalContext.current
    var granted by remember { mutableStateOf(hasLocationPermission(ctx)) }
    var location by remember { mutableStateOf<Location?>(null) }
    var available by remember { mutableStateOf(true) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        granted = hasLocationPermission(ctx)
    }
    val lifecycle = LocalLifecycleOwner.current.lifecycle

    DisposableEffect(granted, lifecycle) {
        if (!granted) return@DisposableEffect onDispose { }
        val lm = ctx.getSystemService(LocationManager::class.java)
        val listener = LocationListener { location = it }
        fun start() {
            val enabled = lm.getProviders(true)
            val order = buildList {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add(LocationManager.FUSED_PROVIDER) // AOSP, not GMS
                add(LocationManager.GPS_PROVIDER)
                add(LocationManager.NETWORK_PROVIDER)
            }.filter { it in enabled }
            available = order.isNotEmpty()
            if (location == null) {
                location = order.mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }.maxByOrNull { it.time }
            }
            order.firstOrNull()?.let { runCatching { lm.requestLocationUpdates(it, 5_000L, 5f, listener, Looper.getMainLooper()) } }
        }
        fun stop() = lm.removeUpdates(listener)
        val observer = LifecycleEventObserver { _, e ->
            when (e) {
                Lifecycle.Event.ON_RESUME -> start()
                Lifecycle.Event.ON_PAUSE -> stop()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer); stop() }
    }

    return LocationUi(granted, location, available) {
        launcher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
    }
}

/**
 * Compass heading in degrees from TRUE north (0..360) using the rotation-vector sensor,
 * or null if the watch has none. Only listens while the screen is composed and resumed.
 */
@Composable
fun rememberHeading(location: Location?): Float? {
    val ctx = LocalContext.current
    val sm = remember { ctx.getSystemService(SensorManager::class.java) }
    val sensor = remember { sm?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) } ?: return null
    var heading by remember { mutableStateOf<Float?>(null) }
    val declination = location?.let {
        GeomagneticField(it.latitude.toFloat(), it.longitude.toFloat(), it.altitude.toFloat(), System.currentTimeMillis()).declination
    } ?: 0f
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(sensor, lifecycle) {
        val rot = FloatArray(9)
        val orient = FloatArray(3)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                SensorManager.getRotationMatrixFromVector(rot, e.values)
                SensorManager.getOrientation(rot, orient)
                val deg = ((Math.toDegrees(orient[0].toDouble()) + 360) % 360).toFloat()
                val prev = heading
                // Light low-pass filter that handles the 359 -> 0 wrap
                heading = if (prev == null) deg else {
                    val diff = ((deg - prev + 540) % 360) - 180
                    (prev + diff * 0.25f + 360) % 360
                }
            }
            override fun onAccuracyChanged(s: Sensor?, a: Int) = Unit
        }
        val observer = LifecycleEventObserver { _, e ->
            when (e) {
                Lifecycle.Event.ON_RESUME -> sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
                Lifecycle.Event.ON_PAUSE -> sm.unregisterListener(listener)
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer); sm.unregisterListener(listener) }
    }
    return heading?.let { (it + declination + 360) % 360 }
}
