package com.pujoroute.wear

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Shader
import android.location.Location
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import com.pujoroute.wear.data.PujoRepository
import com.pujoroute.wear.data.RouteOptimizer
import com.pujoroute.wear.data.UserStore
import com.pujoroute.wear.ui.EmergencyScreen
import com.pujoroute.wear.ui.HomeScreen
import com.pujoroute.wear.ui.LocationUi
import com.pujoroute.wear.ui.MetroLinesScreen
import com.pujoroute.wear.ui.NavigateScreen
import com.pujoroute.wear.ui.NearbyScreen
import com.pujoroute.wear.ui.PandalDetailScreen
import com.pujoroute.wear.ui.PandalListScreen
import com.pujoroute.wear.ui.PanjikaScreen
import com.pujoroute.wear.ui.DayScreen
import com.pujoroute.wear.ui.PassportScreen
import com.pujoroute.wear.ui.PujoTheme
import com.pujoroute.wear.ui.RouteScreen
import com.pujoroute.wear.ui.RouteSetupScreen
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.LocalDateTime

/**
 * JVM screenshot tests (Robolectric native graphics, no emulator).
 * Writes round, black-background PNGs to wear/screenshots/<config>/<screen>.png
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
abstract class ScreenshotBase(private val configName: String, private val fontScale: Float = 1f) {
    @get:Rule val compose = createComposeRule()

    private val now = LocalDateTime.of(2026, 10, 5, 10, 0)
    private val repo by lazy { PujoRepository.get(RuntimeEnvironment.getApplication()) }
    private val store by lazy { UserStore.get(RuntimeEnvironment.getApplication()) }
    // Fake fix near Maddox Square, Ballygunge
    private val fix by lazy {
        Location("test").apply { latitude = 22.5262; longitude = 88.3637; time = System.currentTimeMillis() }
    }

    private fun shot(name: String, content: @Composable () -> Unit) {
        var view: android.view.View? = null
        compose.setContent {
            view = LocalView.current.rootView
            val d = LocalDensity.current
            // Report a round screen (as a Galaxy Watch does) so TimeText and chips use their round layouts
            val cfg = android.content.res.Configuration(LocalConfiguration.current).apply {
                screenLayout = (screenLayout and android.content.res.Configuration.SCREENLAYOUT_ROUND_MASK.inv()) or
                    android.content.res.Configuration.SCREENLAYOUT_ROUND_YES
            }
            CompositionLocalProvider(LocalDensity provides Density(d.density, fontScale), LocalConfiguration provides cfg,
                androidx.compose.ui.platform.LocalContext provides androidx.compose.ui.platform.LocalContext.current.createConfigurationContext(cfg)) {
                PujoTheme { Box(Modifier.fillMaxSize().background(Color.Black)) { content() } }
            }
        }
        compose.waitForIdle()
        val v = view!!
        val src = Bitmap.createBitmap(v.width, v.height, Bitmap.Config.ARGB_8888)
        v.draw(Canvas(src))
        val size = minOf(src.width, src.height)
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        Canvas(out).apply {
            drawColor(android.graphics.Color.BLACK)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP) }
            drawCircle(size / 2f, size / 2f, size / 2f, paint)
        }
        val dir = File(System.getProperty("screenshotDir") ?: "build/screenshots", configName).apply { mkdirs() }
        File(dir, "$name.png").outputStream().use { out.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    private val maddox get() = repo.pandals.first { it.name.contains("Maddox", true) }

    @Test fun home() = shot("01_home_countdown") { HomeScreen(repo, store, now) {} }
    @Test fun panjika() = shot("02_panjika") { PanjikaScreen(repo.calendar.days, now, false, {}) {} }
    @Test fun day() = shot("03_panjika_ashtami") { DayScreen(repo.calendar.days.first { it.id == "ashtami" }, false) }
    @Test fun pandalList() = shot("04_pandal_list_south") {
        val south = repo.zones.first { it.first == "South" }.second
        PandalListScreen("South (${south.size})", south, emptySet(), {})
    }
    @Test fun pandalDetail() = shot("05_pandal_detail") { PandalDetailScreen(maddox, true, false, {}, {}, {}) }
    @Test fun navigate() = shot("06_navigate_compass") {
        val target = repo.pandals.first { it.name.contains("Ekdalia", true) }
        NavigateScreen(target, LocationUi(true, fix), heading = 20f, visited = false) {}
    }
    @Test fun nearby() = shot("07_nearby") { NearbyScreen(repo.mappable, LocationUi(true, fix)) {} }
    @Test fun routeSetup() = shot("08_route_setup") { RouteSetupScreen(repo.zones.map { it.first }, LocationUi(true, fix)) { _, _, _ -> } }
    @Test fun route() = shot("09_route") {
        val r = RouteOptimizer.plan(repo.zones.first { it.first == "South" }.second.filter { it.isMappable }, 5, fix.latitude, fix.longitude)
        RouteScreen(r.stops, setOf(r.stops.first().id), {}, {}, {}, {})
    }
    @Test fun passport() = shot("10_passport") { PassportScreen(repo, repo.pandals.take(4).map { it.id }.toSet()) {} }
    @Test fun metro() = shot("11_metro") { MetroLinesScreen(repo.metro) {} }
    @Test fun emergency() = shot("12_emergency") { EmergencyScreen(repo.emergency) {} }
}

/** Small round (Galaxy Watch 40/41 mm class): 384 x 384 px */
@Config(sdk = [35], qualifiers = "w192dp-h192dp-round-watch-xhdpi")
class SmallRoundScreenshots : ScreenshotBase("small_round_384")

/** Large round (Galaxy Watch 44/45/47 mm class): 450 x 450 px */
@Config(sdk = [35], qualifiers = "w225dp-h225dp-round-watch-xhdpi")
class LargeRoundScreenshots : ScreenshotBase("large_round_450")

/** Small round at the largest accessibility font scale */
@Config(sdk = [35], qualifiers = "w192dp-h192dp-round-watch-xhdpi")
class SmallRoundLargeFontScreenshots : ScreenshotBase("small_round_384_font130", fontScale = 1.3f)
