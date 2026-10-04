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
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

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

    @Test fun shashthiIsFriday16October() {
        // Vishuddha (Belur Math) and Beni Madhab panjikas both put Shashthi / Kalparambha / Bodhon on Fri 16 Oct 2026:
        // https://eisamay.com/astrology/religion-and-rituals/durga-puja-2026-dates-timings-sasthi-saptami-ashtami-navami-dashami-bisudhha-siddhanta-prachin-panjika-puja-nirghonto/200533534.cms
        // https://benimadhabsilpanjika.com/durga-puja-2026/
        val shashthi = days.first { it.id == "shashthi" }
        assertEquals("2026-10-16", shashthi.date)
        assertEquals("Friday, 16 October 2026", shashthi.dateFormatted)
        assertEquals("Fri 16 Oct", Countdown.shortDate(shashthi))
        // Tithi times are unchanged.
        assertEquals("2026-10-16T03:26:00", shashthi.tithiStart)
        assertEquals("2026-10-17T05:55:00", shashthi.tithiEnd)

        val onPanchami = Countdown.state(days, LocalDateTime.of(2026, 10, 15, 20, 0))
        onPanchami as CountdownState.Today
        assertEquals("panchami", onPanchami.day.id)
        assertEquals("shashthi", onPanchami.next?.id)

        val onShashthi = Countdown.state(days, LocalDateTime.of(2026, 10, 16, 6, 0))
        onShashthi as CountdownState.Today
        assertEquals("shashthi", onShashthi.day.id)
        assertEquals("saptami", onShashthi.next?.id)

        // 17 Oct is no longer a puja day in the calendar: the countdown points at Saptami (Sun 18 Oct).
        val on17 = Countdown.state(days, LocalDateTime.of(2026, 10, 17, 12, 0))
        on17 as CountdownState.Upcoming
        assertEquals("saptami", on17.day.id)
        assertEquals(1, on17.daysLeft)
    }

    @Test fun datesMatchPhoneAppPanjika() {
        // Android App/assets/data/panjika_2026.json + lib/data/puja_calendar_data.dart on main (PR #5)
        val expected = mapOf(
            "mahalaya" to "Saturday, 10 October 2026",
            "panchami" to "Thursday, 15 October 2026",
            "shashthi" to "Friday, 16 October 2026",
            "saptami" to "Sunday, 18 October 2026",
            "ashtami" to "Monday, 19 October 2026",
            "nabami" to "Tuesday, 20 October 2026",
            "dashami" to "Wednesday, 21 October 2026",
            "lakshmi_puja" to "Sunday, 25 October 2026",
        )
        assertEquals(expected, days.associate { it.id to it.dateFormatted })
    }

    @Test fun everyCountdownTargetFallsOnItsDisplayedDate() {
        val displayed = DateTimeFormatter.ofPattern("EEEE, d MMMM yyyy", Locale.ENGLISH)
        val sorted = days.sortedBy { it.date }
        assertEquals("calendar must be in date order", days, sorted)
        assertEquals("one day per date", days.size, days.map { it.date }.toSet().size)
        days.forEachIndexed { i, d ->
            val date = LocalDate.parse(d.date)
            // Displayed date (incl. weekday) is exactly the countdown's target date.
            assertEquals(d.id, date.format(displayed), d.dateFormatted)
            assertEquals(d.id, date.format(DateTimeFormatter.ofPattern("EEE d MMM", Locale.ENGLISH)), Countdown.shortDate(d))

            // The countdown leading up to this day ends at 00:00 IST of its displayed date.
            val prev = days.getOrNull(i - 1)
            val before = if (prev == null || LocalDate.parse(prev.date) != date.minusDays(1)) {
                date.minusDays(1).atTime(12, 0)
            } else {
                null // the previous day is itself a puja day; covered by its Today.next below
            }
            if (before != null) {
                val s = Countdown.state(days, before)
                s as CountdownState.Upcoming
                assertEquals(d.id, s.day.id)
                assertEquals(d.id, date.atStartOfDay(), before.plus(s.untilStart))
                assertEquals(d.id, d.dateFormatted, before.plus(s.untilStart).format(displayed))
            }
            // On the displayed date, from first to last minute, this is "today".
            listOf(date.atStartOfDay(), date.atTime(23, 59)).forEach { t ->
                val s = Countdown.state(days, t)
                s as CountdownState.Today
                assertEquals(d.id, s.day.id)
                assertEquals(d.id, days.getOrNull(i + 1)?.id, s.next?.id)
            }
        }
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
        val located = pandals.filter { !it.isLocationUnverified }
        assertTrue(located.all { it.metro.isNotBlank() && it.line.isNotBlank() && it.gate.isNotBlank() })
        // Phase 3: placeholder locations suggest no station and stay out of Nearby / routes.
        val unverified = pandals.filter { it.isLocationUnverified }
        assertEquals(109, unverified.size)
        assertTrue(unverified.all { it.metro.isBlank() && it.gate.startsWith("Location unverified") && !it.isMappable })
        assertEquals(15, pandals.count { !it.isListed })
        assertTrue(pandals.any { it.isHeritage } && pandals.any { !it.isHeritage })
        val metro = PujoParser.metro(asset("metro.json"))
        val stations = metro.lines.flatMap { l -> l.stations.map { it.name } }.toSet()
        assertTrue(located.all { it.metro in stations })
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
        listOf("112", "100", "101", "102", "1091", "1098", "1073").forEach { assertTrue("missing $it", it in all) }
        assertTrue("108 is not a general ambulance number in WB", "108" !in all)
        assertTrue(em.hospitals.isNotEmpty() && em.police.isNotEmpty())
        assertEquals("03322143230", dialable("033-2214-3230"))
        assertEquals("112", dialable(" 112 "))
    }
}
