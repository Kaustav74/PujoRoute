package com.pujoroute.wear.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme

val Saffron = Color(0xFFFF9800)
val Sindoor = Color(0xFFD32F2F)
val Gold = Color(0xFFFFC107)

private val PujoColors = Colors(
    primary = Saffron,
    primaryVariant = Color(0xFFE65100),
    secondary = Gold,
    secondaryVariant = Color(0xFFFFA000),
    error = Sindoor,
    onPrimary = Color.Black,
    onSecondary = Color.Black,
    onError = Color.White,
    background = Color.Black, // AMOLED: true black
    onBackground = Color.White,
    surface = Color(0xFF2A1A12),
    onSurface = Color.White,
    onSurfaceVariant = Color(0xFFE0C9B8),
)

@Composable
fun PujoTheme(content: @Composable () -> Unit) {
    MaterialTheme(colors = PujoColors, content = content)
}
