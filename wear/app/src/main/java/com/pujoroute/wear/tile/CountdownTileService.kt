package com.pujoroute.wear.tile

import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.expand
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.material.Text
import androidx.wear.protolayout.material.Typography
import androidx.wear.protolayout.material.layouts.PrimaryLayout
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.ListenableFuture
import com.pujoroute.wear.MainActivity
import com.pujoroute.wear.data.Countdown
import com.pujoroute.wear.data.CountdownState
import com.pujoroute.wear.data.PujoRepository
import com.pujoroute.wear.data.UserStore
import com.pujoroute.wear.data.nowIst

/** Glanceable "next puja day" countdown Tile. Offline, no Play Services. */
class CountdownTileService : TileService() {

    private fun <T> immediate(value: T): ListenableFuture<T> =
        CallbackToFutureAdapter.getFuture { it.set(value); "tile" }

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val repo = PujoRepository.get(this)
        val state = Countdown.state(repo.calendar.days, nowIst())
        val nextStop = UserStore.get(this).nextStopId()?.let { repo.pandalById[it] }
        val (top, big, bottom) = when (state) {
            is CountdownState.Upcoming -> Triple(
                state.day.titleEn,
                if (state.daysLeft == 1L) "Tomorrow" else "${state.daysLeft} days",
                Countdown.shortDate(state.day),
            )
            is CountdownState.Today -> Triple(state.day.titleEn, "Today", state.next?.let { "Next: ${it.titleEn}" } ?: "")
            is CountdownState.Finished -> Triple("Shubho Bijoya", "See you", "next year!")
        }

        val launch = ModifiersBuilders.Clickable.Builder()
            .setId("open")
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName(MainActivity::class.java.name)
                            .build()
                    ).build()
            ).build()

        val footer = nextStop?.let { "Next stop: ${it.name}" } ?: bottom
        val layout = PrimaryLayout.Builder(requestParams.deviceConfiguration)
            .setResponsiveContentInsetEnabled(true)
            .setPrimaryLabelTextContent(
                Text.Builder(this, top).setTypography(Typography.TYPOGRAPHY_CAPTION1)
                    .setColor(argb(0xFFFFC107.toInt())).setMaxLines(2).build()
            )
            .setContent(
                Text.Builder(this, big).setTypography(Typography.TYPOGRAPHY_DISPLAY3)
                    .setColor(argb(0xFFFFFFFF.toInt())).build()
            )
            .setSecondaryLabelTextContent(
                Text.Builder(this, footer).setTypography(Typography.TYPOGRAPHY_CAPTION2)
                    .setColor(argb(0xFFFF9800.toInt())).setMaxLines(2).build()
            )
            .build()

        val root = LayoutElementBuilders.Box.Builder()
            .setWidth(expand()).setHeight(expand())
            .setModifiers(ModifiersBuilders.Modifiers.Builder().setClickable(launch).build())
            .addContent(layout)
            .build()

        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setFreshnessIntervalMillis(30 * 60 * 1000L)
            .setTileTimeline(TimelineBuilders.Timeline.fromLayoutElement(root))
            .build()
        return immediate(tile)
    }

    override fun onTileResourcesRequest(requestParams: RequestBuilders.ResourcesRequest): ListenableFuture<ResourceBuilders.Resources> =
        immediate(ResourceBuilders.Resources.Builder().setVersion(RESOURCES_VERSION).build())

    private companion object {
        const val RESOURCES_VERSION = "1"
    }
}
