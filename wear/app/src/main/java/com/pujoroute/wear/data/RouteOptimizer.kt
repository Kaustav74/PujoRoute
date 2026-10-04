package com.pujoroute.wear.data

/**
 * Simplified watch port of the phone app's HardenedPujoOptimizer
 * (Android App/lib/services/hardened_pujo_optimizer.dart):
 *  1. greedy nearest-neighbour from the start point, preferring hops <= 1200 m
 *     (relaxed to 1800 m, then plain nearest, so the requested stop count is still met);
 *  2. 2-opt local search (max 300 passes) with the start anchored and the end free.
 * There is no "home-bound terminal" on the watch; routes are open walking paths.
 */
object RouteOptimizer {
    private const val MAX_STEP_M = 1200.0
    private const val RELAXED_STEP_M = 1800.0
    private const val EPS = 1e-6

    data class Leg(val pandal: Pandal, val meters: Double, val minutes: Int)
    data class Route(val stops: List<Pandal>, val legs: List<Leg>, val totalMeters: Double) {
        val totalMinutes get() = legs.sumOf { it.minutes }
    }

    /**
     * @param pool candidate pandals (for example one zone)
     * @param startLat/startLon the walker's position; if null, the route starts at the
     *        pool's most popular pandal nearest the pool centroid.
     */
    fun plan(pool: List<Pandal>, stops: Int, startLat: Double? = null, startLon: Double? = null): Route {
        val candidates = pool.filter { it.lat != 0.0 && it.lon != 0.0 }.distinctBy { it.id }
        if (candidates.isEmpty() || stops <= 0) return Route(emptyList(), emptyList(), 0.0)

        val (sLat, sLon) = if (startLat != null && startLon != null) startLat to startLon
        else candidates.map { it.lat }.average() to candidates.map { it.lon }.average()

        val remaining = candidates.toMutableList()
        val path = mutableListOf<Pandal>()
        var curLat = sLat
        var curLon = sLon
        while (path.size < stops && remaining.isNotEmpty()) {
            val byDist = remaining.map { it to Geo.distance(curLat, curLon, it.lat, it.lon) }
            val next = (byDist.filter { it.second <= MAX_STEP_M }.takeIf { it.isNotEmpty() && path.isNotEmpty() }
                ?: byDist.filter { it.second <= RELAXED_STEP_M }.takeIf { it.isNotEmpty() && path.isNotEmpty() }
                ?: byDist)
                .minWith(compareBy<Pair<Pandal, Double>>({ it.second }, { it.first.rank })).first
            path += next
            remaining -= next
            curLat = next.lat
            curLon = next.lon
        }
        val optimized = twoOpt(path, sLat, sLon)
        return build(optimized, sLat, sLon, includeStartLeg = startLat != null)
    }

    /** Total length of an open path that starts at (sLat, sLon). */
    fun pathLength(path: List<Pandal>, sLat: Double, sLon: Double): Double {
        if (path.isEmpty()) return 0.0
        var sum = Geo.distance(sLat, sLon, path[0].lat, path[0].lon)
        for (i in 0 until path.size - 1) sum += Geo.distance(path[i], path[i + 1])
        return sum
    }

    /**
     * 2-opt on an open path whose virtual node 0 is the fixed start point.
     * Reversing path[i..j] replaces edges (i-1,i) and (j,j+1) with (i-1,j) and (i,j+1);
     * when j is the last stop there is no (j,j+1) edge because the end is free.
     */
    fun twoOpt(path: List<Pandal>, sLat: Double, sLon: Double, maxPasses: Int = 300): List<Pandal> {
        if (path.size < 3) return path
        var best = path.toMutableList()
        fun d(aLat: Double, aLon: Double, b: Pandal) = Geo.distance(aLat, aLon, b.lat, b.lon)
        var improved = true
        var passes = 0
        while (improved && passes < maxPasses) {
            improved = false
            passes++
            val n = best.size
            loop@ for (i in 0 until n - 1) {
                val prevLat = if (i == 0) sLat else best[i - 1].lat
                val prevLon = if (i == 0) sLon else best[i - 1].lon
                for (j in i + 1 until n) {
                    val before = d(prevLat, prevLon, best[i]) + (if (j + 1 < n) Geo.distance(best[j], best[j + 1]) else 0.0)
                    val after = d(prevLat, prevLon, best[j]) + (if (j + 1 < n) Geo.distance(best[i], best[j + 1]) else 0.0)
                    if (after < before - EPS) {
                        best = (best.subList(0, i) + best.subList(i, j + 1).reversed() + best.subList(j + 1, n)).toMutableList()
                        improved = true
                        break@loop
                    }
                }
            }
        }
        return best
    }

    fun build(stops: List<Pandal>, sLat: Double, sLon: Double, includeStartLeg: Boolean): Route {
        val legs = stops.mapIndexed { i, p ->
            val m = when {
                i > 0 -> Geo.distance(stops[i - 1], p)
                includeStartLeg -> Geo.distance(sLat, sLon, p.lat, p.lon)
                else -> 0.0
            }
            Leg(p, m, if (m == 0.0) 0 else Geo.walkMinutes(m))
        }
        return Route(stops, legs, legs.sumOf { it.meters })
    }
}
