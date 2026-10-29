package com.handytools.app.ui

import android.content.Context
import android.content.Intent
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Shapes
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ---------------------------------------------------------------------------------------------
// Tokens. One accent, two modes. Everything in tools/ references these — never a raw hex.
// ---------------------------------------------------------------------------------------------

object HandyColors {
    val Accent = Color(0xFF1F5EFF)
    val AccentPressed = Color(0xFF1649D6)
    // Single source of truth for the brand accent in non-Compose contexts (overlays,
    // launcher-icon bitmaps) that can't read a Compose Color. Same value as Accent.
    const val AccentArgb: Int = 0xFF1F5EFF.toInt()
    // Brand gradient for the generated home-screen icon mock (light → accent → dark).
    val AccentGradient = listOf(Color(0xFF2B68FF), Color(0xFF1F5EFF), Color(0xFF1649D6))
    val AccentSoftLight = Color(0xFFE8EEFF)
    val AccentSoftDark = Color(0xFF16224A)
    val Danger = Color(0xFFE53935)
    val Success = Color(0xFF2E7D32)
    val Amber = Color(0xFFB26A00)
    val WarningSoftLight = Color(0xFFFFF4E5)
    val WarningSoftDark = Color(0xFF2A2214)
    val StickyLight = Color(0xFFFFF6B3)
    val StickyDark = Color(0xFF3A3418)

    val BackgroundLight = Color(0xFFF6F7FB)
    val SurfaceLight = Color(0xFFFFFFFF)
    val TextPrimaryLight = Color(0xFF0E0E12)
    val TextSecondaryLight = Color(0xFF5C5F6E)
    val BorderLight = Color(0x14000000)

    val BackgroundDark = Color(0xFF0E0E12)
    val SurfaceDark = Color(0xFF16161C)
    val SurfaceRaisedDark = Color(0xFF1C1C24)
    val TextPrimaryDark = Color(0xFFF2F2F5)
    val TextSecondaryDark = Color(0xFFA3A6B5)
    val BorderDark = Color(0x1AFFFFFF)
}

object HandyTokens {
    val Space4 = 4.dp; val Space8 = 8.dp; val Space12 = 12.dp; val Space16 = 16.dp
    val Space20 = 20.dp; val Space24 = 24.dp; val Space32 = 32.dp; val Space48 = 48.dp
    val RadiusSmall = 8.dp; val RadiusInput = 12.dp; val RadiusCard = 16.dp; val RadiusSheet = 24.dp
    val TouchTarget = 48.dp
    val PrimaryButtonHeight = 52.dp
    val CompactButtonHeight = 40.dp
    val ChipHeight = 36.dp
    val AdReservedHeight = 60.dp
    val Gutter = 20.dp
}

/** Mode-dependent colors that Material's scheme doesn't have slots for. */
data class HandyPalette(
    val accentSoft: Color, val warningSoft: Color, val sticky: Color, val border: Color,
    val surfaceRaised: Color, val textSecondary: Color, val isDark: Boolean
)

val LocalHandy = staticCompositionLocalOf {
    HandyPalette(HandyColors.AccentSoftLight, HandyColors.WarningSoftLight, HandyColors.StickyLight,
        HandyColors.BorderLight, HandyColors.SurfaceLight, HandyColors.TextSecondaryLight, false)
}

object Handy {
    val palette: HandyPalette @Composable get() = LocalHandy.current
}

private val LightColors = lightColorScheme(
    primary = HandyColors.Accent, onPrimary = Color.White,
    primaryContainer = HandyColors.AccentSoftLight, onPrimaryContainer = HandyColors.Accent,
    secondary = HandyColors.Accent, onSecondary = Color.White,
    secondaryContainer = HandyColors.AccentSoftLight, onSecondaryContainer = HandyColors.Accent,
    background = HandyColors.BackgroundLight, onBackground = HandyColors.TextPrimaryLight,
    surface = HandyColors.SurfaceLight, onSurface = HandyColors.TextPrimaryLight,
    surfaceVariant = HandyColors.SurfaceLight, onSurfaceVariant = HandyColors.TextSecondaryLight,
    surfaceContainer = HandyColors.SurfaceLight, surfaceContainerHigh = HandyColors.SurfaceLight,
    surfaceContainerLow = HandyColors.SurfaceLight, surfaceContainerHighest = HandyColors.SurfaceLight,
    error = HandyColors.Danger, onError = Color.White,
    errorContainer = HandyColors.WarningSoftLight, onErrorContainer = HandyColors.TextPrimaryLight,
    outline = HandyColors.BorderLight, outlineVariant = HandyColors.BorderLight
)

private val DarkColors = darkColorScheme(
    primary = HandyColors.Accent, onPrimary = Color.White,
    primaryContainer = HandyColors.AccentSoftDark, onPrimaryContainer = Color(0xFFDCE5FF),
    secondary = HandyColors.Accent, onSecondary = Color.White,
    secondaryContainer = HandyColors.AccentSoftDark, onSecondaryContainer = Color(0xFFDCE5FF),
    background = HandyColors.BackgroundDark, onBackground = HandyColors.TextPrimaryDark,
    surface = HandyColors.SurfaceDark, onSurface = HandyColors.TextPrimaryDark,
    surfaceVariant = HandyColors.SurfaceRaisedDark, onSurfaceVariant = HandyColors.TextSecondaryDark,
    surfaceContainer = HandyColors.SurfaceDark, surfaceContainerHigh = HandyColors.SurfaceRaisedDark,
    surfaceContainerLow = HandyColors.SurfaceDark, surfaceContainerHighest = HandyColors.SurfaceRaisedDark,
    error = HandyColors.Danger, onError = Color.White,
    errorContainer = HandyColors.WarningSoftDark, onErrorContainer = HandyColors.TextPrimaryDark,
    outline = HandyColors.BorderDark, outlineVariant = HandyColors.BorderDark
)

private val HandyShapes = Shapes(
    extraSmall = RoundedCornerShape(HandyTokens.RadiusSmall),
    small = RoundedCornerShape(HandyTokens.RadiusInput),
    medium = RoundedCornerShape(HandyTokens.RadiusCard),
    large = RoundedCornerShape(HandyTokens.RadiusSheet),
    extraLarge = RoundedCornerShape(28.dp)
)

private val base = Typography()
private val HandyTypography = Typography(
    displayLarge = base.displayLarge.copy(fontSize = 34.sp, lineHeight = 40.sp, fontWeight = FontWeight.Bold, letterSpacing = (-0.5).sp),
    headlineMedium = base.headlineMedium.copy(fontSize = 34.sp, lineHeight = 40.sp, fontWeight = FontWeight.Bold, letterSpacing = (-0.5).sp),
    headlineLarge = base.headlineLarge.copy(fontSize = 34.sp, lineHeight = 40.sp, fontWeight = FontWeight.Bold, letterSpacing = (-0.5).sp),
    headlineSmall = base.headlineSmall.copy(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.SemiBold),
    titleLarge = base.titleLarge.copy(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.SemiBold),
    titleMedium = base.titleMedium.copy(fontSize = 17.sp, lineHeight = 23.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge = base.bodyLarge.copy(fontSize = 16.sp, lineHeight = 23.sp),
    bodyMedium = base.bodyMedium.copy(fontSize = 15.sp, lineHeight = 22.sp),
    bodySmall = base.bodySmall.copy(fontSize = 13.sp, lineHeight = 18.sp),
    labelLarge = base.labelLarge.copy(fontSize = 16.sp, lineHeight = 23.sp, fontWeight = FontWeight.SemiBold),
    labelMedium = base.labelMedium.copy(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.Medium),
    labelSmall = base.labelSmall.copy(fontSize = 12.sp, lineHeight = 16.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.6.sp)
)

@Composable
fun HandyTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val palette = if (dark) HandyPalette(HandyColors.AccentSoftDark, HandyColors.WarningSoftDark, HandyColors.StickyDark,
        HandyColors.BorderDark, HandyColors.SurfaceRaisedDark, HandyColors.TextSecondaryDark, true)
    else HandyPalette(HandyColors.AccentSoftLight, HandyColors.WarningSoftLight, HandyColors.StickyLight,
        HandyColors.BorderLight, HandyColors.SurfaceLight, HandyColors.TextSecondaryLight, false)
    CompositionLocalProvider(LocalHandy provides palette) {
        MaterialTheme(colorScheme = if (dark) DarkColors else LightColors, typography = HandyTypography, shapes = HandyShapes) {
            androidx.compose.material3.Surface(color = MaterialTheme.colorScheme.background, contentColor = MaterialTheme.colorScheme.onBackground) { content() }
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Components. Three button styles, one card, one permission card, rows, chips.
// ---------------------------------------------------------------------------------------------

/** Primary: pill, accent, 52dp, full width. Scales 0.98 while pressed. */
@Composable
fun HPrimaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, icon: ImageVector? = null, onClick: () -> Unit) {
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    Button(
        onClick = onClick, enabled = enabled, interactionSource = src,
        modifier = modifier.fillMaxWidth().height(HandyTokens.PrimaryButtonHeight).scale(if (pressed) 0.98f else 1f).semantics { contentDescription = text },
        colors = ButtonDefaults.buttonColors(
            containerColor = if (pressed) HandyColors.AccentPressed else HandyColors.Accent,
            disabledContainerColor = Handy.palette.accentSoft, disabledContentColor = HandyColors.Accent.copy(alpha = 0.5f)
        )
    ) {
        if (icon != null) { Icon(icon, null, Modifier.size(20.dp)); Spacer(Modifier.width(HandyTokens.Space8)) }
        Text(text, style = MaterialTheme.typography.labelLarge)
    }
}

/** Secondary: pill, transparent, 1.5dp hairline border, primary text. */
@Composable
fun HSecondaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, onClick: () -> Unit) {
    OutlinedButton(
        onClick = onClick, enabled = enabled,
        modifier = modifier.fillMaxWidth().height(HandyTokens.PrimaryButtonHeight).semantics { contentDescription = text },
        border = BorderStroke(1.5.dp, Handy.palette.border),
        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.onSurface)
    ) { Text(text, style = MaterialTheme.typography.labelLarge) }
}

/** Text: no chrome, accent label, 44dp. */
@Composable
fun HTextButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = modifier.height(44.dp).semantics { contentDescription = text }) { Text(text, style = MaterialTheme.typography.labelLarge, color = HandyColors.Accent) }
}

/** Compact primary used inside cards (40dp). */
@Composable
fun HCompactButton(text: String, onClick: () -> Unit) {
    Button(onClick = onClick, modifier = Modifier.height(HandyTokens.CompactButtonHeight).semantics { contentDescription = text },
        contentPadding = ButtonDefaults.ButtonWithIconContentPadding) { Text(text, style = MaterialTheme.typography.labelMedium.copy(fontSize = 14.sp)) }
}

/** Level-1 card: surface + hairline. */
@Composable
fun HCard(modifier: Modifier = Modifier, onClick: (() -> Unit)? = null, content: @Composable () -> Unit) {
    val m = if (onClick != null) modifier.clickable(onClick = onClick) else modifier
    Card(
        modifier = m, shape = MaterialTheme.shapes.medium,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, Handy.palette.border),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) { content() }
}

/** Home grid card: icon in an accentSoft circle, name, one-line blurb. */
@Composable
fun ToolCard(name: String, blurb: String, icon: ImageVector, onClick: () -> Unit) {
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    Card(
        modifier = Modifier.fillMaxWidth().height(140.dp).scale(if (pressed) 0.98f else 1f)
            .clickable(interactionSource = src, indication = null, onClick = onClick),
        shape = MaterialTheme.shapes.medium,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, Handy.palette.border),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(Modifier.padding(HandyTokens.Space16), verticalArrangement = Arrangement.SpaceBetween) {
            Box(Modifier.size(40.dp).background(Handy.palette.accentSoft, CircleShape), contentAlignment = Alignment.Center) {
                Icon(icon, null, Modifier.size(22.dp), tint = HandyColors.Accent)
            }
            Spacer(Modifier.weight(1f))
            Text(name, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(blurb, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

/**
 * Amber permission card: OS name, one-line why, optional privacy line, one button to the exact
 * settings page. When granted, the card collapses (height -> 0 + fade over base) and is replaced
 * by nothing.
 */
@Composable
fun PermissionCard(title: String, why: String, granted: Boolean, intent: Intent, buttonText: String = "Allow", privacy: String? = null) {
    val ctx: Context = LocalContext.current
    val reduceMotion = rememberReduceMotion()
    androidx.compose.animation.AnimatedVisibility(
        visible = !granted,
        enter = androidx.compose.animation.fadeIn(tween(HandyMotion.BASE_MS, easing = HandyMotion.EnterEasing)),
        exit = androidx.compose.animation.shrinkVertically(tween(if (reduceMotion) HandyMotion.FAST_MS else HandyMotion.BASE_MS, easing = HandyMotion.ExitEasing)) +
            androidx.compose.animation.fadeOut(tween(if (reduceMotion) HandyMotion.FAST_MS else HandyMotion.BASE_MS))
    ) {
        Card(
            Modifier.fillMaxWidth().padding(bottom = HandyTokens.Space12),
            shape = MaterialTheme.shapes.medium,
            colors = CardDefaults.cardColors(containerColor = Handy.palette.warningSoft),
            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
        ) {
            Row(Modifier.padding(HandyTokens.Space16)) {
                Icon(Icons.Outlined.Shield, null, Modifier.size(24.dp), tint = HandyColors.Amber)
                Spacer(Modifier.width(HandyTokens.Space12))
                Column {
                    Text(title, style = MaterialTheme.typography.titleMedium.copy(fontSize = 16.sp))
                    Spacer(Modifier.height(HandyTokens.Space4))
                    Text(why, style = MaterialTheme.typography.bodyMedium.copy(fontSize = 14.sp))
                    if (privacy != null) {
                        Spacer(Modifier.height(HandyTokens.Space4))
                        Text(privacy, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    }
                    Spacer(Modifier.height(HandyTokens.Space12))
                    HCompactButton(buttonText) { ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                }
            }
        }
    }
}

@Composable
fun ToolHeader(title: String, subtitle: String) {
    Column(Modifier.padding(bottom = HandyTokens.Space16)) {
        Text(title, style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(HandyTokens.Space4))
        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
    }
}

/** 56dp toggle row with a hairline below. Light haptic on toggle. */
@Composable
fun BigToggle(label: String, on: Boolean, onToggle: (Boolean) -> Unit) {
    val ctx: Context = LocalContext.current
    Column {
        Row(
            Modifier.fillMaxWidth().height(56.dp),
            horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            Switch(checked = on, onCheckedChange = { v -> HandyHaptics.light(ctx); onToggle(v) },
                colors = SwitchDefaults.colors(checkedTrackColor = HandyColors.Accent, checkedThumbColor = Color.White))
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Handy.palette.border))
    }
}

/** Label + live value on one line, slider under. Value uses tabular digits so it doesn't jitter. */
@Composable
fun SliderRow(label: String, valueText: String, value: Float, onChange: (Float) -> Unit, range: ClosedFloatingPointRange<Float>, steps: Int = 0, onFinished: (() -> Unit)? = null) {
    Column(Modifier.fillMaxWidth().padding(vertical = HandyTokens.Space8)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            Text(valueText, style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum"))
        }
        Slider(value = value, onValueChange = onChange, valueRange = range, steps = steps, onValueChangeFinished = onFinished)
    }
}

/** Pill chip, 36dp. Selected = accentSoft fill + accent text + accent border. Light haptic on select. */
@Composable
fun HChip(text: String, selected: Boolean, onClick: () -> Unit) {
    val ctx: Context = LocalContext.current
    FilterChip(
        selected = selected, onClick = { HandyHaptics.light(ctx); onClick() },
        label = { Text(text, style = MaterialTheme.typography.labelMedium.copy(fontSize = 14.sp), maxLines = 1, softWrap = false) },
        shape = CircleShape, modifier = Modifier.height(HandyTokens.ChipHeight).semantics { contentDescription = text },
        colors = FilterChipDefaults.filterChipColors(
            selectedContainerColor = Handy.palette.accentSoft, selectedLabelColor = HandyColors.Accent,
            containerColor = MaterialTheme.colorScheme.surface, labelColor = MaterialTheme.colorScheme.onSurface
        ),
        border = FilterChipDefaults.filterChipBorder(enabled = true, selected = selected,
            borderColor = Handy.palette.border, selectedBorderColor = HandyColors.Accent, selectedBorderWidth = 1.5.dp)
    )
}

@Composable
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
fun ChipRow(content: @Composable RowScope.() -> Unit) {
    // Chips wrap onto new lines instead of clipping at the screen edge (FlowRowScope is a RowScope).
    androidx.compose.foundation.layout.FlowRow(
        horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8),
        verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)
    ) { content() }
}

/** Secondary text line under a control: the honest-limit note. */
@Composable
fun LimitNote(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = HandyTokens.Space8))
}

/** Empty state: icon in accentSoft circle, one line, optional second line. */
@Composable
fun EmptyState(icon: ImageVector, line: String, sub: String? = null) {
    Column(Modifier.fillMaxWidth().padding(top = HandyTokens.Space48), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(64.dp).background(Handy.palette.accentSoft, CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(28.dp), tint = HandyColors.Accent)
        }
        Spacer(Modifier.height(HandyTokens.Space16))
        Text(line, style = MaterialTheme.typography.bodyLarge)
        if (sub != null) Text(sub, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = HandyTokens.Space4))
    }
}
