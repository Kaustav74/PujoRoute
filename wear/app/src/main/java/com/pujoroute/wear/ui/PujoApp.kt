package com.pujoroute.wear.ui

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.net.toUri
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import androidx.wear.tiles.TileService
import com.pujoroute.wear.data.PujoRepository
import com.pujoroute.wear.data.RouteOptimizer
import com.pujoroute.wear.data.UserStore
import com.pujoroute.wear.data.dialable
import com.pujoroute.wear.data.nowIst
import com.pujoroute.wear.tile.CountdownTileService
import kotlinx.coroutines.delay

object Routes {
    const val HOME = "home"
    const val PANJIKA = "panjika"
    const val PANDALS = "pandals"
    const val SEARCH = "search"
    const val BOOKMARKS = "bookmarks"
    const val NEARBY = "nearby"
    const val ROUTE = "route"
    const val ROUTE_SETUP = "route_setup"
    const val PASSPORT = "passport"
    const val METRO = "metro"
    const val EMERGENCY = "emergency"
}

@Composable
fun PujoApp(repo: PujoRepository, store: UserStore, startDestination: String = Routes.HOME) {
    val ctx = LocalContext.current
    LaunchedEffect(store) {
        store.addListener { runCatching { TileService.getUpdater(ctx).requestUpdate(CountdownTileService::class.java) } }
    }
    PujoTheme {
        val nav = rememberSwipeDismissableNavController()
        val openPandal: (String) -> Unit = { nav.navigate("pandal/$it") }
        val openNavigate: (String) -> Unit = { nav.navigate("navigate/$it") }
        SwipeDismissableNavHost(navController = nav, startDestination = startDestination) {
            composable(Routes.HOME) {
                HomeScreen(repo, store, rememberNow()) { nav.navigate(it) }
            }
            composable(Routes.PANJIKA) {
                PanjikaScreen(repo.calendar.days, rememberNow(), store.beniMadhab, store::updateBeniMadhab) { nav.navigate("day/$it") }
            }
            composable("day/{id}", listOf(navArgument("id") { type = NavType.StringType })) { e ->
                repo.calendar.days.firstOrNull { it.id == e.arguments?.getString("id") }?.let { DayScreen(it, store.beniMadhab) }
            }
            composable(Routes.PANDALS) {
                PandalsScreen(repo, store) { nav.navigate(it) }
            }
            composable("zone/{index}", listOf(navArgument("index") { type = NavType.IntType })) { e ->
                repo.zones.getOrNull(e.arguments?.getInt("index") ?: -1)?.let { (zone, list) ->
                    PandalListScreen("$zone (${list.size})", list, store.visited, openPandal)
                }
            }
            composable(Routes.SEARCH) { SearchScreen(repo, store.visited, openPandal) }
            composable(Routes.BOOKMARKS) {
                PandalListScreen("Bookmarks", store.bookmarks.mapNotNull { repo.pandalById[it] }.sortedBy { it.name }, store.visited, openPandal,
                    empty = "No bookmarks yet. Open a pandal and tap Bookmark.")
            }
            composable("pandal/{id}", listOf(navArgument("id") { type = NavType.StringType })) { e ->
                repo.pandalById[e.arguments?.getString("id")]?.let { p ->
                    PandalDetailScreen(p, p.id in store.visited, p.id in store.bookmarks,
                        onNavigate = { openNavigate(p.id) },
                        onVisited = { store.toggleVisited(p.id) },
                        onBookmark = { store.toggleBookmark(p.id) })
                }
            }
            composable("navigate/{id}", listOf(navArgument("id") { type = NavType.StringType })) { e ->
                repo.pandalById[e.arguments?.getString("id")]?.let { p ->
                    val loc = rememberWatchLocation()
                    NavigateScreen(p, loc, rememberHeading(loc.location), p.id in store.visited) { store.toggleVisited(p.id) }
                }
            }
            composable(Routes.NEARBY) { NearbyScreen(repo.mappable, rememberWatchLocation(), openPandal) }
            composable(Routes.ROUTE_SETUP) {
                val loc = rememberWatchLocation()
                RouteSetupScreen(repo.zones.map { it.first }, loc) { zone, stops, useLocation ->
                    val pool = (if (zone == null) repo.pandals else repo.zones.first { it.first == zone }.second).filter { it.isMappable }
                    val l = loc.location.takeIf { useLocation }
                    val route = RouteOptimizer.plan(pool, stops, l?.latitude, l?.longitude)
                    store.saveRoute(route.stops.map { it.id })
                    nav.popBackStack()
                    if (nav.currentDestination?.route != Routes.ROUTE) nav.navigate(Routes.ROUTE)
                }
            }
            composable(Routes.ROUTE) {
                RouteScreen(
                    stops = store.route.mapNotNull { repo.pandalById[it] },
                    done = store.routeDone,
                    onToggleDone = store::toggleDone,
                    onNavigate = openNavigate,
                    onPlan = { nav.navigate(Routes.ROUTE_SETUP) },
                    onClear = { store.saveRoute(emptyList()) },
                )
            }
            composable(Routes.PASSPORT) { PassportScreen(repo, store.visited, openPandal) }
            composable(Routes.METRO) { MetroLinesScreen(repo.metro) { nav.navigate("line/$it") } }
            composable("line/{i}", listOf(navArgument("i") { type = NavType.IntType })) { e ->
                val i = e.arguments?.getInt("i") ?: 0
                repo.metro.lines.getOrNull(i)?.let { line ->
                    MetroLineScreen(line, repo.mappable) { s -> nav.navigate("station/$i/$s") }
                }
            }
            composable("station/{i}/{s}", listOf(navArgument("i") { type = NavType.IntType }, navArgument("s") { type = NavType.IntType })) { e ->
                repo.metro.lines.getOrNull(e.arguments?.getInt("i") ?: 0)?.stations?.getOrNull(e.arguments?.getInt("s") ?: 0)?.let { st ->
                    StationScreen(st, repo.mappable, openPandal)
                }
            }
            composable(Routes.EMERGENCY) { EmergencyScreen(repo.emergency) { dial(ctx, it) } }
        }
    }
}

/** Current IST time, refreshed every minute only while the screen is resumed. */
@Composable
fun rememberNow(): java.time.LocalDateTime {
    var now by remember { mutableStateOf(nowIst()) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            while (true) {
                now = nowIst()
                delay(60_000)
            }
        }
    }
    return now
}

/** Opens the dialer pre-filled (ACTION_DIAL needs no CALL_PHONE permission). */
fun dial(ctx: Context, number: String) {
    try {
        ctx.startActivity(Intent(Intent.ACTION_DIAL, "tel:${dialable(number)}".toUri()))
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(ctx, "No dialer on this watch. Call $number from your phone.", Toast.LENGTH_LONG).show()
    }
}
