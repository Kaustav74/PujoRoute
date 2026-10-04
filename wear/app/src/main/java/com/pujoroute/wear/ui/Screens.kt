package com.pujoroute.wear.ui

import android.app.Activity
import android.app.RemoteInput
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Card
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import androidx.wear.input.RemoteInputIntentHelper
import com.pujoroute.wear.data.Countdown
import com.pujoroute.wear.data.CountdownState
import com.pujoroute.wear.data.EmergencyData
import com.pujoroute.wear.data.Geo
import com.pujoroute.wear.data.MetroData
import com.pujoroute.wear.data.MetroLine
import com.pujoroute.wear.data.Pandal
import com.pujoroute.wear.data.Passport
import com.pujoroute.wear.data.PujaDay
import com.pujoroute.wear.data.PujoParser
import com.pujoroute.wear.data.PujoRepository
import com.pujoroute.wear.data.RouteOptimizer
import com.pujoroute.wear.data.Station
import com.pujoroute.wear.data.UserStore
import java.time.LocalDateTime

// ================================================================= Home
@Composable
fun HomeScreen(repo: PujoRepository, store: UserStore, now: LocalDateTime, go: (String) -> Unit) {
    val state = Countdown.state(repo.calendar.days, now)
    val next = store.nextStopId()?.let { repo.pandalById[it] }
    // Title as the first list item below the TimeText (no curved title, so nothing collides with the clock)
    PujoScreen {
        header("PujoRoute")
        note("Durga Puja 2026")
        item { CountdownCard(state) { go("day/$it") } }
        if (next != null) item { NavChip("Next stop: ${next.name}", "Route · tap to navigate", primary = true) { go("navigate/${next.id}") } }
        item { NavChip("Pandals", "Zones · search · bookmarks") { go(Routes.PANDALS) } }
        item { NavChip("Nearby", "Closest pandals (GPS)") { go(Routes.NEARBY) } }
        item { NavChip("Route planner", if (store.route.isEmpty()) "Plan a walking circuit" else "${store.routeDone.size}/${store.route.size} stops done") { go(Routes.ROUTE) } }
        item { NavChip("Panjika", "Tithi & muhurat") { go(Routes.PANJIKA) } }
        item { NavChip("Passport", "${store.visited.size} stamped · ${Passport.level(store.visited.size)}") { go(Routes.PASSPORT) } }
        item { NavChip("Metro", "Lines & stations") { go(Routes.METRO) } }
        item { NavChip("Emergency", "112 · 100 · 102 · 101", color = Sindoor) { go(Routes.EMERGENCY) } }
    }
}

@Composable
fun CountdownCard(state: CountdownState, onDay: (String) -> Unit) {
    val (day, big, small) = when (state) {
        is CountdownState.Upcoming -> Triple(
            state.day,
            if (state.daysLeft == 1L) "Tomorrow" else "${state.daysLeft} days",
            "${Countdown.formatDuration(state.untilStart)} · ${Countdown.shortDate(state.day)}",
        )
        is CountdownState.Today -> Triple(
            state.day, "Today",
            state.next?.let { "Next: ${it.titleEn}, ${Countdown.shortDate(it)}" } ?: Countdown.shortDate(state.day),
        )
        is CountdownState.Finished -> Triple(state.last, "Asche bochor abar hobe!", "Durga Puja 2026 is over")
    }
    Card(onClick = { onDay(day.id) }, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(if (state is CountdownState.Finished) "Shubho Bijoya" else day.titleEn,
                style = MaterialTheme.typography.caption1, color = MaterialTheme.colors.secondary, textAlign = TextAlign.Center)
            Text(big, style = MaterialTheme.typography.title1, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center)
            Text(small, style = MaterialTheme.typography.caption2, textAlign = TextAlign.Center)
            if (state !is CountdownState.Finished) {
                Text("Tithi ${Countdown.formatTithi(day)}", style = MaterialTheme.typography.caption3,
                    color = MaterialTheme.colors.onSurfaceVariant, textAlign = TextAlign.Center)
            }
        }
    }
}

// ================================================================= Panjika
@Composable
fun PanjikaScreen(days: List<PujaDay>, now: LocalDateTime, beniMadhab: Boolean, setBeni: (Boolean) -> Unit, onDay: (String) -> Unit) {
    val today = now.toLocalDate().toString()
    PujoScreen {
        header("Panjika")
        item { CountdownCard(Countdown.state(days, now), onDay) }
        item { ToggleRow("Beni Madhab mode", if (beniMadhab) "Traditional para" else "Belur Math (default)", beniMadhab, switch = true, onToggle = setBeni) }
        days.forEach { d ->
            item {
                NavChip(d.titleEn, Countdown.shortDate(d) + if (d.date == today) " · Today" else "", primary = d.date == today) { onDay(d.id) }
            }
        }
    }
}

@Composable
fun DayScreen(day: PujaDay, beniMadhab: Boolean) {
    val tithi = (if (beniMadhab && day.tithiTimingsTrad.isNotBlank()) day.tithiTimingsTrad else day.tithiTimings)
        .split("|").joinToString("\n") { it.trim() }
    val moments = if (beniMadhab && day.auspiciousMomentsTrad.isNotEmpty()) day.auspiciousMomentsTrad else day.auspiciousMoments
    PujoScreen {
        header(day.titleEn)
        item { Text(day.titleBn, style = MaterialTheme.typography.body2, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()) }
        label("Date", day.dateFormatted.ifBlank { Countdown.shortDate(day) })
        label(if (beniMadhab) "Tithi (Beni Madhab)" else "Tithi (Belur Math)", listOf(day.tithiName, tithi).filter { it.isNotBlank() }.joinToString("\n"))
        if (!beniMadhab) label(day.muhuratTitle.ifBlank { "Muhurat" }, day.muhuratWindow)
        if (moments.isNotEmpty()) label("Muhurats", moments.joinToString("\n") { "• $it" })
        label("Expected crowd", day.crowdForecast)
    }
}

// ================================================================= Pandals
@Composable
fun PandalsScreen(repo: PujoRepository, store: UserStore, go: (String) -> Unit) {
    PujoScreen {
        header("Pandals")
        item { NavChip("Search", "Voice or keyboard", primary = true) { go(Routes.SEARCH) } }
        item { NavChip("Bookmarks", "${store.bookmarks.size} saved") { go(Routes.BOOKMARKS) } }
        header("By zone")
        repo.zones.forEachIndexed { i, (zone, list) -> item { NavChip(zone, "${list.size} pandals") { go("zone/$i") } } }
    }
}

@Composable
fun PandalListScreen(title: String, pandals: List<Pandal>, visited: Set<String>, onPandal: (String) -> Unit, empty: String = "Nothing here yet.") {
    PujoScreen {
        header(title)
        if (pandals.isEmpty()) note(empty)
        items(pandals.size, key = { pandals[it].id }) { i ->
            val p = pandals[i]
            NavChip((if (p.id in visited) "✓ " else "") + p.name, if (p.metro.isNotBlank()) "Ⓜ ${p.metro}" else p.area) { onPandal(p.id) }
        }
    }
}

@Composable
fun SearchScreen(repo: PujoRepository, visited: Set<String>, onPandal: (String) -> Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { r ->
        if (r.resultCode == Activity.RESULT_OK) {
            r.data?.let { RemoteInput.getResultsFromIntent(it)?.getCharSequence("q")?.toString() }?.let { query = it.trim() }
        }
    }
    val ctx = androidx.compose.ui.platform.LocalContext.current
    val ask = {
        val intent = RemoteInputIntentHelper.createActionRemoteInputIntent()
        RemoteInputIntentHelper.putRemoteInputsExtra(intent, listOf(RemoteInput.Builder("q").setLabel("Pandal, area or metro").build()))
        try { launcher.launch(intent) } catch (_: Exception) {
            android.widget.Toast.makeText(ctx, "Text input not available", android.widget.Toast.LENGTH_SHORT).show()
        }
    }
    val results = remember(query) { PujoParser.search(repo.pandals, query) }
    PujoScreen {
        header("Search")
        item { NavChip(if (query.isBlank()) "Tap to search" else "\"$query\"", "Speak or type", primary = true) { ask() } }
        if (query.isNotBlank()) {
            if (results.isEmpty()) note("No pandal matches \"$query\".") else note("${results.size} result${if (results.size == 1) "" else "s"}")
            items(results.size, key = { results[it].id }) { i ->
                val p = results[i]
                NavChip((if (p.id in visited) "✓ " else "") + p.name, "${p.zone} · Ⓜ ${p.metro}") { onPandal(p.id) }
            }
        } else {
            note("Search by name, landmark, metro station or area, e.g. \"Behala\", \"Kalighat\".")
        }
    }
}

@Composable
fun PandalDetailScreen(p: Pandal, visited: Boolean, bookmarked: Boolean, onNavigate: () -> Unit, onVisited: () -> Unit, onBookmark: () -> Unit) {
    PujoScreen {
        header(p.name)
        note(p.categoryLabel)
        item { NavChip("Navigate", "Compass & distance", primary = true, onClick = onNavigate) }
        item { ToggleRow("Passport stamp", if (visited) "Visited ✓" else "Mark visited", visited) { onVisited() } }
        item { ToggleRow("Bookmark", null, bookmarked) { onBookmark() } }
        label("Zone", listOf(p.zone, p.area).filter { it.isNotBlank() }.joinToString(" · "))
        label("Landmark", p.landmark)
        label("Nearest metro", listOf(p.metro, p.line).filter { it.isNotBlank() }.joinToString(" · "))
        label("Gate", p.gate)
        label("About", p.about)
    }
}

// ================================================================= Nearby & compass
@Composable
fun NearbyScreen(pandals: List<Pandal>, loc: LocationUi, onPandal: (String) -> Unit) {
    PujoScreen {
        header("Nearby")
        when {
            !loc.hasPermission -> {
                note("PujoRoute uses GPS only while this screen is open.")
                item { NavChip("Allow location", null, primary = true, onClick = loc.requestPermission) }
            }
            !loc.providerAvailable -> note("Location is off. Turn it on in watch Settings → Location.")
            loc.location == null -> note("Getting GPS fix… stay outdoors with a clear sky.")
            else -> {
                val list = Geo.nearest(pandals, loc.location.latitude, loc.location.longitude)
                list.forEach { r ->
                    item { NavChip(r.pandal.name, "${Geo.formatDistance(r.meters)} · ${Geo.walkMinutes(r.meters)} min walk") { onPandal(r.pandal.id) } }
                }
            }
        }
    }
}

@Composable
fun NavigateScreen(p: Pandal, loc: LocationUi, heading: Float?, visited: Boolean, onVisited: () -> Unit) {
    val l = loc.location
    val dist = l?.let { Geo.distance(it.latitude, it.longitude, p.lat, p.lon) }
    val bearing = l?.let { Geo.bearing(it.latitude, it.longitude, p.lat, p.lon) }
    // Scrollable round list, so a long name or a large font never clips at the round edge
    PujoScreen {
        item {
            Text(p.name, style = MaterialTheme.typography.caption1, color = Gold, textAlign = TextAlign.Center, maxLines = 2,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
        }
        when {
            !loc.hasPermission -> {
                note("GPS is used only while this screen is open.")
                item { NavChip("Allow location", null, primary = true, onClick = loc.requestPermission) }
            }
            !loc.providerAvailable -> note("Location is off. Turn it on in watch Settings → Location.")
            bearing == null -> note("Getting GPS fix…")
            else -> {
                item {
                    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CompassArrow(rotation = if (heading != null) (bearing - heading).toFloat() else bearing.toFloat(), Modifier.size(60.dp))
                    }
                }
                item {
                    Text(Geo.formatDistance(dist!!), style = MaterialTheme.typography.title2, fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                }
                note("${Geo.walkMinutes(dist!!)} min walk · " + if (heading != null) "follow the arrow" else "head ${Geo.cardinal(bearing)} (no compass)")
            }
        }
        item {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                CompactChip(onClick = onVisited, label = { Text(if (visited) "Visited ✓" else "Stamp visit") })
            }
        }
    }
}

@Composable
fun CompassArrow(rotation: Float, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        rotate(rotation) {
            val w = size.width
            val h = size.height
            val path = Path().apply {
                moveTo(w / 2, 0f)
                lineTo(w * 0.85f, h * 0.9f)
                lineTo(w / 2, h * 0.68f)
                lineTo(w * 0.15f, h * 0.9f)
                close()
            }
            drawPath(path, Saffron)
        }
    }
}

// ================================================================= Route planner
@Composable
fun RouteSetupScreen(zones: List<String>, loc: LocationUi, onBuild: (zone: String?, stops: Int, useLocation: Boolean) -> Unit) {
    val zoneOptions = listOf<String?>(null) + zones
    val stopOptions = listOf(3, 5, 8, 10)
    var zi by rememberSaveable { mutableIntStateOf(0) }
    var si by rememberSaveable { mutableIntStateOf(1) }
    var useLoc by rememberSaveable { mutableStateOf(false) }
    PujoScreen {
        header("Route planner")
        item { NavChip("Zone: ${zoneOptions[zi] ?: "All Kolkata"}", "Tap to change") { zi = (zi + 1) % zoneOptions.size } }
        item { NavChip("Stops: ${stopOptions[si]}", "Tap to change") { si = (si + 1) % stopOptions.size } }
        item {
            ToggleRow("Start from my location", when {
                !useLoc -> "Off: start at zone centre"
                !loc.hasPermission -> "Needs location permission"
                loc.location == null -> "Waiting for GPS…"
                else -> "GPS fix ready"
            }, useLoc, switch = true) { on -> useLoc = on; if (on && !loc.hasPermission) loc.requestPermission() }
        }
        item { NavChip("Build route", "Nearest-neighbour + 2-opt", primary = true) { onBuild(zoneOptions[zi], stopOptions[si], useLoc) } }
    }
}

@Composable
fun RouteScreen(
    stops: List<Pandal>, done: Set<String>, onToggleDone: (String) -> Unit, onNavigate: (String) -> Unit,
    onPlan: () -> Unit, onClear: () -> Unit,
) {
    PujoScreen {
        header("Route")
        if (stops.isEmpty()) {
            note("No route yet. Pick a zone and stop count to build a walking circuit.")
            item { NavChip("Plan a route", null, primary = true, onClick = onPlan) }
            return@PujoScreen
        }
        val route = RouteOptimizer.build(stops, 0.0, 0.0, includeStartLeg = false)
        val next = stops.firstOrNull { it.id !in done }
        note("${done.count { d -> stops.any { it.id == d } }}/${stops.size} stops done")
        note("${Geo.formatDistance(route.totalMeters)} · ~${route.totalMinutes} min walk")
        if (next != null) item { NavChip("Next: ${next.name}", "Navigate", primary = true) { onNavigate(next.id) } }
        else note("Circuit complete! Shubho Pujo 🪔")
        route.legs.forEachIndexed { i, leg ->
            item {
                ToggleRow(
                    "${i + 1}. ${leg.pandal.name}",
                    if (i == 0) "Start · Ⓜ ${leg.pandal.metro}" else "+${Geo.formatDistance(leg.meters)} · ${leg.minutes} min",
                    leg.pandal.id in done,
                ) { onToggleDone(leg.pandal.id) }
            }
        }
        item { NavChip("New route", null, onClick = onPlan) }
        item { NavChip("Clear route", null, onClick = onClear) }
    }
}

// ================================================================= Passport
@Composable
fun PassportScreen(repo: PujoRepository, visited: Set<String>, onPandal: (String) -> Unit) {
    val badges = Passport.badges(visited, repo.pandalById)
    PujoScreen {
        header("Passport")
        item {
            Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("${visited.size}", style = MaterialTheme.typography.display3, color = Gold)
                Text("pandals stamped", style = MaterialTheme.typography.caption2)
                Text(Passport.level(visited.size), style = MaterialTheme.typography.caption1, color = Saffron, textAlign = TextAlign.Center)
            }
        }
        header("Badges ${badges.count { it.unlocked }}/${badges.size}")
        badges.forEach { b ->
            item {
                NavChip((if (b.unlocked) b.icon + " " else "🔒 ") + b.title, b.rule, primary = b.unlocked) { }
            }
        }
        if (visited.isNotEmpty()) {
            header("Visited")
            visited.mapNotNull { repo.pandalById[it] }.sortedBy { it.name }.forEach { p ->
                item { NavChip(p.name, p.zone) { onPandal(p.id) } }
            }
        } else note("Stamp a pandal from its detail screen or by finishing route stops.")
    }
}

// ================================================================= Metro
@Composable
fun MetroLinesScreen(metro: MetroData, onLine: (Int) -> Unit) {
    PujoScreen {
        header("Metro")
        metro.lines.forEachIndexed { i, l ->
            item { NavChip(l.name, "${l.stations.first().name} – ${l.stations.last().name}", color = lineColor(l.name)) { onLine(i) } }
        }
        note("Each pandal's nearest station and gate are on its detail screen.")
    }
}

@Composable
fun MetroLineScreen(line: MetroLine, pandals: List<Pandal>, onStation: (Int) -> Unit) {
    val counts = remember(line) { pandals.groupingBy { it.metro }.eachCount() }
    PujoScreen {
        header(line.name)
        line.stations.forEachIndexed { i, s ->
            item { NavChip(s.name, "${counts[s.name] ?: 0} pandals nearest") { onStation(i) } }
        }
    }
}

@Composable
fun StationScreen(st: Station, pandals: List<Pandal>, onPandal: (String) -> Unit) {
    val list = remember(st) {
        pandals.filter { it.metro == st.name }.map { it to Geo.distance(st.lat, st.lon, it.lat, it.lon) }.sortedBy { it.second }
    }
    PujoScreen {
        header("Ⓜ ${st.name}")
        if (list.isEmpty()) note("No pandals list this as their nearest station.")
        list.forEach { (p, m) -> item { NavChip(p.name, "${Geo.formatDistance(m)} from station") { onPandal(p.id) } } }
    }
}

private fun lineColor(name: String) = when {
    name.startsWith("Blue") -> Color(0xFF1565C0)
    name.startsWith("Green") -> Color(0xFF2E7D32)
    name.startsWith("Purple") -> Color(0xFF6A1B9A)
    name.startsWith("Orange") -> Color(0xFFE65100)
    else -> Color.DarkGray
}

// ================================================================= Emergency
@Composable
fun EmergencyScreen(em: EmergencyData, onDial: (String) -> Unit) {
    PujoScreen {
        header("Emergency")
        note("Tap to open the dialer. If your watch can't call (no LTE), dial the number shown from your phone.")
        em.helplines.forEach { h ->
            h.numbers.forEach { n -> item { NavChip(n, h.label, color = Sindoor) { onDial(n) } } }
        }
        header("Police help booths")
        em.police.forEach { b ->
            b.numbers.filter { it.length > 4 }.forEach { n -> item { NavChip(n, b.name) { onDial(n) } } }
        }
        header("Hospitals (24x7)")
        em.hospitals.forEach { h -> item { NavChip(h.phone, h.name) { onDial(h.phone) } } }
    }
}
