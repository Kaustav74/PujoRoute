package com.pujoroute.wear

import com.pujoroute.wear.data.Geo
import com.pujoroute.wear.data.Pandal
import com.pujoroute.wear.data.PujoParser
import com.pujoroute.wear.data.RouteOptimizer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class RouteAndGeoTest {
    private val all = PujoParser.pandals(File("src/main/assets/pandals.json").readText())
    private fun p(id: String, lat: Double, lon: Double) = Pandal(id = id, name = id, zone = "Test", lat = lat, lon = lon)

    @Test fun haversineKnownDistance() {
        // Esplanade -> Park Street metro, about 1.45 km
        val d = Geo.distance(22.5647, 88.3524, 22.5516, 88.3516)
        assertEquals(1460.0, d, 30.0)
        assertEquals(0.0, Geo.distance(22.5, 88.3, 22.5, 88.3), 1e-9)
    }

    @Test fun bearingCardinals() {
        assertEquals(0.0, Geo.bearing(22.0, 88.0, 23.0, 88.0), 0.5)
        assertEquals(90.0, Geo.bearing(22.0, 88.0, 22.0, 89.0), 0.5)
        assertEquals("S", Geo.cardinal(Geo.bearing(23.0, 88.0, 22.0, 88.0)))
    }

    @Test fun nearestSortsByDistance() {
        val maddox = all.first { it.name.contains("Maddox", true) }
        val list = Geo.nearest(all, maddox.lat, maddox.lon, limit = 10)
        assertEquals(10, list.size)
        assertEquals(maddox.id, list.first().pandal.id)
        assertTrue(list.zipWithNext().all { (a, b) -> a.meters <= b.meters })
    }

    @Test fun walkTimeUsesPhonePace() {
        assertEquals(10, Geo.walkMinutes(750.0))
        assertEquals(1, Geo.walkMinutes(10.0))
        assertEquals("750 m", Geo.formatDistance(750.0))
        assertEquals("1.5 km", Geo.formatDistance(1500.0))
    }

    @Test fun planReturnsRequestedUniqueStops() {
        val south = all.filter { it.zone == "South" }
        for (n in listOf(3, 5, 8, 10)) {
            val r = RouteOptimizer.plan(south, n)
            assertEquals(n, r.stops.size)
            assertEquals(n, r.stops.map { it.id }.toSet().size)
            assertTrue(r.stops.all { it.zone == "South" })
            assertEquals(n, r.legs.size)
        }
        assertTrue(RouteOptimizer.plan(emptyList(), 5).stops.isEmpty())
        assertEquals(2, RouteOptimizer.plan(south.take(2), 5).stops.size)
    }

    @Test fun planStartsNearestToUserLocation() {
        val maddox = all.first { it.name.contains("Maddox", true) }
        val r = RouteOptimizer.plan(all, 5, maddox.lat, maddox.lon)
        assertEquals(maddox.id, r.stops.first().id)
        // Greedy + 2-opt should keep a compact walk: every hop within the relaxed limit in a dense area
        assertTrue(r.legs.drop(1).all { it.meters < 1800 })
    }

    @Test fun twoOptRemovesCrossing() {
        // Points on a line visited out of order: 0 -> 3 -> 2 -> 1 -> 4 (crossing back and forth)
        val a = p("a", 22.500, 88.30); val b = p("b", 22.501, 88.30); val c = p("c", 22.502, 88.30)
        val d = p("d", 22.503, 88.30); val e = p("e", 22.504, 88.30)
        val bad = listOf(a, d, c, b, e)
        val fixed = RouteOptimizer.twoOpt(bad, 22.4995, 88.30)
        assertEquals(listOf("a", "b", "c", "d", "e"), fixed.map { it.id })
        assertTrue(RouteOptimizer.pathLength(fixed, 22.4995, 88.30) < RouteOptimizer.pathLength(bad, 22.4995, 88.30))
    }

    @Test fun twoOptNeverWorseThanGreedy() {
        val north = all.filter { it.zone == "North" }
        val greedy = north.take(8)
        val opt = RouteOptimizer.twoOpt(greedy, greedy[0].lat, greedy[0].lon)
        assertTrue(RouteOptimizer.pathLength(opt, greedy[0].lat, greedy[0].lon) <= RouteOptimizer.pathLength(greedy, greedy[0].lat, greedy[0].lon) + 1e-6)
        assertEquals(greedy.toSet(), opt.toSet())
    }
}
