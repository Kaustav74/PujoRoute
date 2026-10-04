package com.pujoroute.wear.data

import kotlinx.serialization.Serializable

@Serializable
data class CalendarData(val timezone: String = "Asia/Kolkata", val days: List<PujaDay>)

@Serializable
data class PujaDay(
    val id: String,
    val titleEn: String,
    val titleBn: String = "",
    val subTitle: String = "",
    /** Local IST date, yyyy-MM-dd */
    val date: String,
    val dateFormatted: String = "",
    /** Local IST date-time, yyyy-MM-ddTHH:mm:ss */
    val tithiStart: String,
    val tithiEnd: String,
    val tithiName: String = "",
    val tithiTimings: String = "",
    val muhuratTitle: String = "",
    val muhuratWindow: String = "",
    val auspiciousMoments: List<String> = emptyList(),
    /** Beni Madhab / traditional para mode; empty means "same as Belur Math". */
    val tithiTimingsTrad: String = "",
    val auspiciousMomentsTrad: List<String> = emptyList(),
    val crowdForecast: String = "",
    val crowdLevel: Double = 0.0,
)

@Serializable
data class Pandal(
    val id: String,
    val name: String,
    /** "m" = mega / theme, "h" = heritage (bonedi bari) */
    val cat: String = "m",
    val zone: String,
    val area: String = "",
    val lat: Double = 0.0,
    val lon: Double = 0.0,
    val landmark: String = "",
    val metro: String = "",
    val line: String = "",
    val gate: String = "",
    val about: String = "",
    val rank: Int = 999,
) {
    val isHeritage get() = cat == "h"
    val categoryLabel get() = if (isHeritage) "Heritage (Bonedi Bari)" else "Mega / Theme"
}

@Serializable
data class MetroData(val lines: List<MetroLine>)

@Serializable
data class MetroLine(val name: String, val stations: List<Station>)

@Serializable
data class Station(val name: String, val lat: Double, val lon: Double)
@Serializable
data class EmergencyData(
    val helplines: List<Helpline>,
    val hospitals: List<Hospital>,
    val police: List<PoliceBooth>,
)

@Serializable
data class Helpline(val label: String, val numbers: List<String>)

@Serializable
data class Hospital(val name: String, val zone: String, val phone: String, val address: String = "")

@Serializable
data class PoliceBooth(val name: String, val landmark: String, val numbers: List<String>)
