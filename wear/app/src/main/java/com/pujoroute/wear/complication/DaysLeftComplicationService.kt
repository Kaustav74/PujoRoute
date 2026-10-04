package com.pujoroute.wear.complication

import android.app.PendingIntent
import android.content.Intent
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService
import com.pujoroute.wear.MainActivity
import com.pujoroute.wear.data.Countdown
import com.pujoroute.wear.data.CountdownState
import com.pujoroute.wear.data.PujoRepository
import com.pujoroute.wear.data.nowIst

/** SHORT_TEXT complication: days until the next puja day (e.g. "5d" / "Mahalaya"). Updated hourly by the system. */
class DaysLeftComplicationService : SuspendingComplicationDataSourceService() {

    override fun getPreviewData(type: ComplicationType): ComplicationData? =
        if (type == ComplicationType.SHORT_TEXT) data("5d", "Pujo", "5 days to Mahalaya") else null

    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? {
        if (request.complicationType != ComplicationType.SHORT_TEXT) return null
        return when (val s = Countdown.state(PujoRepository.get(this).calendar.days, nowIst())) {
            is CountdownState.Upcoming -> data("${s.daysLeft}d", short(s.day.titleEn), "${s.daysLeft} days to ${s.day.titleEn}")
            is CountdownState.Today -> data("Today", short(s.day.titleEn), "Today is ${s.day.titleEn}")
            is CountdownState.Finished -> data("🪔", "Bijoya", "Durga Puja 2026 is over")
        }
    }

    private fun short(title: String) = title.removePrefix("Maha ").removePrefix("Bijoya ").removePrefix("Kojagori ").take(8)

    private fun data(text: String, title: String, description: String): ComplicationData {
        val tap = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return ShortTextComplicationData.Builder(
            PlainComplicationText.Builder(text).build(),
            PlainComplicationText.Builder(description).build(),
        ).setTitle(PlainComplicationText.Builder(title).build()).setTapAction(tap).build()
    }
}
