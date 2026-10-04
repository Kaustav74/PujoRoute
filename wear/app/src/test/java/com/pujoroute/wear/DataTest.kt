package com.pujoroute.wear

import com.pujoroute.wear.data.Countdown
import com.pujoroute.wear.data.CountdownState
import com.pujoroute.wear.data.PujoParser
import com.pujoroute.wear.data.dialable
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.Duration
import java.time.LocalDateTime

class DataTest {
    private fun asset(name: String) = File("src/main/assets/$name").readText()
    private val days = PujoParser.calendar(asset("calendar.json")).days

    @Test fun calendarHasAllEightDaysInOrder() {
        assertEquals(
            listOf("mahalaya", "panchami", "shashthi", "saptami", "ashtami", "nabami", "dashami", "lakshmi_puja"),
            days.map { it.id },
        )
        assertEquals("2026-10-10", days.first().date)
        assertEquals("2026-10-25", days.last().date)
    }

    @Test fun countdownBeforeMahalaya() {
        val s = Countdown.state(days, LocalDateTime.of(2026, 10, 5, 1, 30))
        s as CountdownState.Upcoming
        assertEquals("mahalaya", s.day.id)
        assertEquals(5, s.daysLeft)
        assertEquals(Duration.ofHours(4 * 24 + 22).plusMinutes(30), s.untilStart)
        assertEquals("4d 22h", Countdown.formatDuration(s.untilStart))
    }

    @Test fun countdownBetweenMahalayaAndPanchami() {
        // Audited calendar (2eea390): Panchami is Thu 15 Oct 2026
        val s = Countdown.state(days, LocalDateTime.of(2026, 10, 12, 20, 0))
        s as CountdownState.Upcoming
        assertEquals("panchami", s.day.id)
        assertEquals("2026-10-15", s.day.date)
        assertEquals(3, s.daysLeft)
    }

    @Test fun countdownOnAshtamiIsToday() {
        val s = Countdown.state(days, LocalDateTime.of(2026, 10, 19, 23, 59))
        s as CountdownState.Today
        assertEquals("ashtami", s.day.id)
        assertEquals("nabami", s.next?.id)
    }

    @Test fun countdownAfterDashamiPointsToLakshmiPuja() {
        val s = Countdown.state(days, LocalDateTime.of(2026, 10, 22, 9, 0))
        s as CountdownState.Upcoming
        assertEquals("lakshmi_puja", s.day.id)
        assertEquals(3, s.daysLeft)
    }

    @Test fun countdownFinishedAfterSeason() {
        val s = Countdown.state(days, LocalDateTime.of(2026, 10, 26, 0, 0))
        assertTrue(s is CountdownState.Finished)
    }

    @Test fun tithiFormatting() {
        val ashtami = days.first { it.id == "ashtami" }
        assertEquals("18 Oct, 8:30 AM – 19 Oct, 10:52 AM", Countdown.formatTithi(ashtami))
    }

    @Test fun lakshmiPujaNishitaMuhurat() {
        val l = days.first { it.id == "lakshmi_puja" }
        assertEquals("10:56 PM - 11:46 PM", l.muhuratWindow)
        assertEquals("2026-10-25T11:55:00", l.tithiStart)
    }

    @Test fun beniMadhabModeHasTraditionalTimings() {
        assertTrue(days.count { it.tithiTimingsTrad.isNotBlank() } >= 5)
    }

    @Test fun pandalsHaveCoordinatesMetroLineAndGate() {
        val pandals = PujoParser.pandals(asset("pandals.json"))
        assertTrue(pandals.all { it.lat in 21.5..23.5 && it.lon in 87.5..89.5 })
        assertTrue(pandals.all { it.metro.isNotBlank() && it.line.isNotBlank() && it.gate.isNotBlank() })
        assertTrue(pandals.any { it.isHeritage } && pandals.any { !it.isHeritage })
        val metro = PujoParser.metro(asset("metro.json"))
        val stations = metro.lines.flatMap { l -> l.stations.map { it.name } }.toSet()
        assertTrue(pandals.all { it.metro in stations })
    }

    @Test fun searchMatchesNameMetroAndArea() {
        val pandals = PujoParser.pandals(asset("pandals.json"))
        assertTrue(PujoParser.search(pandals, "maddox").any { it.name.contains("Maddox", true) })
        assertTrue(PujoParser.search(pandals, "kalighat").isNotEmpty())
        assertTrue(PujoParser.search(pandals, "behala").all { "behala" in "${it.name} ${it.landmark} ${it.metro} ${it.area} ${it.zone}".lowercase() })
        assertTrue(PujoParser.search(pandals, "   ").isEmpty())
    }

    @Test fun pandalsLoadAndGroupByZone() {
        val pandals = PujoParser.pandals(asset("pandals.json"))
        assertEquals(504, pandals.size)
        assertEquals(pandals.size, pandals.map { it.id }.toSet().size)
        assertTrue(pandals.all { it.name.isNotBlank() && it.zone.isNotBlank() })
        val zones = PujoParser.groupByZone(pandals)
        assertEquals(listOf("North", "Central", "South", "Salt Lake"), zones.map { it.first })
        assertEquals(pandals.size, zones.sumOf { it.second.size })
    }

    @Test fun emergencyNumbersPresentAndDialable() {
        val em = PujoParser.emergency(asset("emergency.json"))
        val all = em.helplines.flatMap { it.numbers }
        listOf("112", "100", "101", "102", "108", "1091", "1073").forEach { assertTrue("missing $it", it in all) }
        assertTrue(em.hospitals.isNotEmpty() && em.police.isNotEmpty())
        assertEquals("03322143230", dialable("033-2214-3230"))
        assertEquals("112", dialable(" 112 "))
    }
}
