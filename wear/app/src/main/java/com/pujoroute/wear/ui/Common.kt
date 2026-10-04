package com.pujoroute.wear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.ScalingLazyListScope
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.ListHeader
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.curvedText
import androidx.wear.compose.material.ToggleChip
import androidx.wear.compose.material.ToggleChipDefaults
import androidx.wear.compose.material.Checkbox
import androidx.wear.compose.material.Switch
import androidx.wear.compose.foundation.rotary.RotaryScrollableDefaults
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.Vignette
import androidx.wear.compose.material.VignettePosition

/** Standard round-screen scaffold: time at top, scroll indicator, rotary/bezel scrolling (built into ScalingLazyColumn). */
@Composable
fun PujoScreen(curvedTitle: String? = null, content: ScalingLazyListScope.() -> Unit) {
    val listState = rememberScalingLazyListState(initialCenterItemIndex = 0)
    Scaffold(
        modifier = Modifier.background(Color.Black),
        timeText = {
            // Standard Wear TimeText: curved along the top edge on round screens, always visible
            TimeText(
                startCurvedContent = curvedTitle?.let { t -> { curvedText(t, color = Saffron) } },
            )
        },
        vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) },
    ) {
        ScalingLazyColumn(
            modifier = Modifier.fillMaxWidth(),
            state = listState,
            // Galaxy Watch rotating bezel / crown
            rotaryScrollableBehavior = RotaryScrollableDefaults.behavior(listState),
            // Top-anchored list: first item starts just below the TimeText on round screens
            autoCentering = null,
            verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.Top),
            contentPadding = PaddingValues(start = 10.dp, end = 10.dp, top = 30.dp, bottom = 48.dp),
            content = content,
        )
    }
}

fun ScalingLazyListScope.header(text: String) = item {
    ListHeader { Text(text, textAlign = TextAlign.Center, color = MaterialTheme.colors.primary, fontWeight = FontWeight.Bold) }
}

fun ScalingLazyListScope.label(title: String, body: String) {
    if (body.isBlank()) return
    item {
        Text(
            title,
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp, start = 8.dp, end = 8.dp),
            style = MaterialTheme.typography.caption2,
            color = MaterialTheme.colors.secondary,
            textAlign = TextAlign.Center,
        )
    }
    item {
        Text(
            body,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            style = MaterialTheme.typography.body2,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
fun NavChip(
    label: String,
    secondary: String? = null,
    primary: Boolean = false,
    color: Color? = null,
    onClick: () -> Unit,
) {
    Chip(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        label = { Text(label, maxLines = 2, overflow = TextOverflow.Ellipsis) },
        secondaryLabel = secondary?.let { { Text(it, maxLines = 1, overflow = TextOverflow.Ellipsis) } },
        colors = when {
            color != null -> ChipDefaults.primaryChipColors(backgroundColor = color, contentColor = Color.White, secondaryContentColor = Color.White)
            primary -> ChipDefaults.primaryChipColors()
            else -> ChipDefaults.secondaryChipColors()
        },
    )
}

@Composable
fun ToggleRow(label: String, secondary: String?, checked: Boolean, switch: Boolean = false, onToggle: (Boolean) -> Unit) {
    ToggleChip(
        modifier = Modifier.fillMaxWidth(),
        checked = checked,
        onCheckedChange = onToggle,
        label = { Text(label, maxLines = 2, overflow = TextOverflow.Ellipsis) },
        secondaryLabel = secondary?.let { { Text(it, maxLines = 1, overflow = TextOverflow.Ellipsis) } },
        toggleControl = { if (switch) Switch(checked = checked) else Checkbox(checked = checked) },
        colors = ToggleChipDefaults.toggleChipColors(),
    )
}

fun ScalingLazyListScope.note(text: String) = item {
    Text(
        text,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 6.dp),
        style = MaterialTheme.typography.caption3,
        color = MaterialTheme.colors.onSurfaceVariant,
        textAlign = TextAlign.Center,
    )
}
