package com.pujoroute.wear.data

import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/** All puja dates/times in the data are Kolkata local time. */
val IST: ZoneId = ZoneId.of("Asia/Kolkata")

fun nowIst(): LocalDateTime = LocalDateTime.now(IST)

sealed interface CountdownState {
    /** A puja day is coming up; [daysLeft] counts calendar days (IST), [untilStart] is time until 00:00 IST of that day. */
    data class Upcoming(val day: PujaDay, val daysLeft: Long, val untilStart: Duration) : CountdownState
    /** Today (IST) is a puja day. */
    data class Today(val day: PujaDay, val next: PujaDay?) : CountdownState
    /** The festival season is over. */
    data class Finished(val last: PujaDay) : CountdownState
}

object Countdown {
    fun state(days: List<PujaDay>, now: LocalDateTime): CountdownState {
        require(days.isNotEmpty()) { "no puja days" }
        val sorted = days.sortedBy { it.date }
        val today = now.toLocalDate()
        sorted.forEachIndexed { i, d ->
            val date = LocalDate.parse(d.date)
            if (date == today) return CountdownState.Today(d, sorted.getOrNull(i + 1))
            if (date.isAfter(today)) {
                return CountdownState.Upcoming(
                    day = d,
                    daysLeft = ChronoUnit.DAYS.between(today, date),
                    untilStart = Duration.between(now, date.atStartOfDay()),
                )
            }
        }
        return CountdownState.Finished(sorted.last())
    }

    private val dayTime = DateTimeFormatter.ofPattern("d MMM, h:mm a", Locale.ENGLISH)
    private val shortDate = DateTimeFormatter.ofPattern("EEE d MMM", Locale.ENGLISH)

    fun formatTithi(day: PujaDay): String =
        "${LocalDateTime.parse(day.tithiStart).format(dayTime)} – ${LocalDateTime.parse(day.tithiEnd).format(dayTime)}"

    fun shortDate(day: PujaDay): String = LocalDate.parse(day.date).format(shortDate)

    /** e.g. "5d 22h" or "3h 12m" */
    fun formatDuration(d: Duration): String {
        val totalMin = d.toMinutes().coerceAtLeast(0)
        val days = totalMin / (24 * 60)
        val hours = (totalMin / 60) % 24
        val mins = totalMin % 60
        return if (days > 0) "${days}d ${hours}h" else "${hours}h ${mins}m"
    }
}

/** Digits (and a leading +) only, for a tel: URI. "033-2214-3230" -> "03322143230". */
fun dialable(number: String): String = number.filter { it.isDigit() || it == '+' }
