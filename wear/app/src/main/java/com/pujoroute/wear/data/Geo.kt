package com.pujoroute.wear.data

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

object Geo {
    private const val EARTH_RADIUS_M = 6_371_000.0
    /** Walking pace used by the phone app (75 m per minute, about 4.5 km/h). */
    const val WALK_M_PER_MIN = 75.0

    fun distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2)
        return EARTH_RADIUS_M * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    fun distance(a: Pandal, b: Pandal) = distance(a.lat, a.lon, b.lat, b.lon)

    /** Initial bearing from point 1 to point 2, degrees clockwise from true north (0..360). */
    fun bearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val p1 = Math.toRadians(lat1)
        val p2 = Math.toRadians(lat2)
        val dl = Math.toRadians(lon2 - lon1)
        val y = sin(dl) * cos(p2)
        val x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        return (Math.toDegrees(atan2(y, x)) + 360.0) % 360.0
    }

    data class Ranked(val pandal: Pandal, val meters: Double)

    /** Pandals sorted by distance from (lat, lon), nearest first. */
    fun nearest(pandals: List<Pandal>, lat: Double, lon: Double, limit: Int = 25): List<Ranked> =
        pandals.asSequence()
            .filter { it.lat != 0.0 && it.lon != 0.0 }
            .map { Ranked(it, distance(lat, lon, it.lat, it.lon)) }
            .sortedBy { it.meters }
            .take(limit)
            .toList()

    fun formatDistance(m: Double): String =
        if (m < 1000) "${m.roundToInt()} m" else String.format(java.util.Locale.ENGLISH, "%.1f km", m / 1000)

    fun walkMinutes(m: Double): Int = maxOf(1, (m / WALK_M_PER_MIN).roundToInt())

    fun cardinal(deg: Double): String =
        listOf("N", "NE", "E", "SE", "S", "SW", "W", "NW")[(((deg % 360) + 360) % 360 / 45.0).roundToInt() % 8]
}
