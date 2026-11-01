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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
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
    // Accent is driven by the active theme (see TenzyTheme / HandyTheme). It's a var so the ~150
    // existing `HandyColors.Accent` references — icon tints, Canvas draw code, gradients — all re-skin
    // when the theme changes, without touching each call site; HandyTheme sets it then rebuilds the
    // tree under key(theme) so every reader re-reads the fresh value. Default = Daylight.
    var Accent = Color(0xFF1F5EFF)
    var AccentPressed = Color(0xFF1649D6)
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
    val accent: Color, val accentPressed: Color,
    val accentSoft: Color, val warningSoft: Color, val sticky: Color, val border: Color,
    val surfaceRaised: Color, val textSecondary: Color, val isDark: Boolean
)

val LocalHandy = staticCompositionLocalOf {
    HandyPalette(Color(0xFF1F5EFF), Color(0xFF1649D6),
        HandyColors.AccentSoftLight, HandyColors.WarningSoftLight, HandyColors.StickyLight,
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

// ---------------------------------------------------------------------------------------------
// Themes. Five looks, matching iOS (Daylight is free + adaptive to system light/dark; the rest are
// Pro and fixed). A theme resolves to a token set; HandyTheme applies it to Material's scheme, the
// HandyPalette, and the HandyColors.Accent var, then rebuilds the tree so every surface re-skins.
// ---------------------------------------------------------------------------------------------

/** The resolved colour tokens a theme renders with, for the current light/dark state. */
data class ResolvedTokens(
    val accent: Color, val accentPressed: Color, val accentSoft: Color,
    val bg: Color, val surface: Color, val surfaceRaised: Color,
    val textPrimary: Color, val textSecondary: Color, val border: Color, val isDark: Boolean
)

enum class TenzyTheme(val title: String, val blurb: String, val isPro: Boolean, val swatch: List<Color>) {
    DAYLIGHT("Daylight", "Clean, bright — the default", false, listOf(Color(0xFF1F5EFF), Color(0xFF1649D6))),
    MIDNIGHT("Midnight", "Dark glass, neon glow", true, listOf(Color(0xFF1E3A8A), Color(0xFF3DE1FF))),
    WARM_PAPER("Warm Paper", "Editorial, warm, matte", true, listOf(Color(0xFFC2502E), Color(0xFFE0795A))),
    NEO_POP("Neo Pop", "Bold, playful, punchy", true, listOf(Color(0xFFFF2D87), Color(0xFFFF8A00))),
    MONO("Mono", "Minimal, stealth", true, listOf(Color(0xFF1A1A1A), Color(0xFF000000)));

    fun tokens(systemDark: Boolean): ResolvedTokens = when (this) {
        DAYLIGHT -> if (systemDark) ResolvedTokens(
            Color(0xFF1F5EFF), Color(0xFF1649D6), HandyColors.AccentSoftDark,
            HandyColors.BackgroundDark, HandyColors.SurfaceDark, HandyColors.SurfaceRaisedDark,
            HandyColors.TextPrimaryDark, HandyColors.TextSecondaryDark, HandyColors.BorderDark, true)
        else ResolvedTokens(
            Color(0xFF1F5EFF), Color(0xFF1649D6), HandyColors.AccentSoftLight,
            HandyColors.BackgroundLight, HandyColors.SurfaceLight, HandyColors.SurfaceLight,
            HandyColors.TextPrimaryLight, HandyColors.TextSecondaryLight, HandyColors.BorderLight, false)
        MIDNIGHT -> fixed(0xFF3DE1FF, 0xFF16B6D6, 0xFF0B0E14, 0xFF141925, 0xFF1C2230, 0xFFEAF2FF, true)
        WARM_PAPER -> fixed(0xFFC2502E, 0xFF9E3F22, 0xFFF6F1E7, 0xFFEFE8D8, 0xFFFFFFFF, 0xFF1C1A17, false)
        NEO_POP -> fixed(0xFFFF2D87, 0xFFD81B6C, 0xFFFBF7F2, 0xFFFFFFFF, 0xFFFFFFFF, 0xFF141414, false)
        MONO -> fixed(0xFFFF5A1F, 0xFFE04715, 0xFFFFFFFF, 0xFFF2F2F2, 0xFFFFFFFF, 0xFF0A0A0A, false)
    }

    /** Fixed-look theme: derive the soft/secondary/border tints from the base tokens (as iOS does). */
    private fun fixed(accent: Long, pressed: Long, bg: Long, surface: Long, raised: Long, text: Long, dark: Boolean): ResolvedTokens {
        val txt = Color(text)
        return ResolvedTokens(
            Color(accent), Color(pressed), Color(accent).copy(alpha = 0.16f),
            Color(bg), Color(surface), Color(raised),
            txt, txt.copy(alpha = 0.62f), txt.copy(alpha = 0.12f), dark)
    }

    companion object { fun from(name: String?): TenzyTheme = entries.firstOrNull { it.name == name } ?: DAYLIGHT }
}

/** Holds the chosen theme (Compose state so a switch re-skins live) and persists it. */
object ThemeStore {
    private const val PREF = "tenzy_theme_prefs"
    private const val KEY = "theme"
    val selected = mutableStateOf<TenzyTheme?>(null)   // null until first loaded from prefs

    fun load(ctx: Context): TenzyTheme {
        selected.value?.let { return it }
        val t = TenzyTheme.from(ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).getString(KEY, null))
        selected.value = t
        return t
    }

    fun set(ctx: Context, t: TenzyTheme) {
        selected.value = t
        ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().putString(KEY, t.name).apply()
    }
}

private fun schemeFor(t: ResolvedTokens) =
    (if (t.isDark) darkColorScheme() else lightColorScheme()).copy(
        primary = t.accent, onPrimary = Color.White,
        primaryContainer = t.accentSoft, onPrimaryContainer = t.accent,
        secondary = t.accent, onSecondary = Color.White,
        secondaryContainer = t.accentSoft, onSecondaryContainer = t.accent,
        background = t.bg, onBackground = t.textPrimary,
        surface = t.surface, onSurface = t.textPrimary,
        surfaceVariant = t.surfaceRaised, onSurfaceVariant = t.textSecondary,
        surfaceContainer = t.surface, surfaceContainerHigh = t.surfaceRaised,
        surfaceContainerLow = t.surface, surfaceContainerHighest = t.surfaceRaised,
        error = HandyColors.Danger, onError = Color.White,
        errorContainer = if (t.isDark) HandyColors.WarningSoftDark else HandyColors.WarningSoftLight,
        onErrorContainer = t.textPrimary,
        outline = t.border, outlineVariant = t.border
    )

@Composable
fun HandyTheme(content: @Composable () -> Unit) {
    val ctx = LocalContext.current
    val premium by com.handytools.app.HandyApp.instance.billing.isPremium.collectAsState()
    val stored = ThemeStore.selected.value ?: ThemeStore.load(ctx)
    // A free user (or a lapsed subscription) always renders Daylight even if a Pro theme is stored.
    val active = if (!premium && stored.isPro) TenzyTheme.DAYLIGHT else stored
    val systemDark = isSystemInDarkTheme()
    val t = active.tokens(systemDark)

    // Drive the global accent var so every `HandyColors.Accent` reference (icon tints, Canvas draws,
    // gradients) re-skins. Set before the keyed subtree builds, so children read the fresh value.
    HandyColors.Accent = t.accent
    HandyColors.AccentPressed = t.accentPressed

    val palette = HandyPalette(
        accent = t.accent, accentPressed = t.accentPressed, accentSoft = t.accentSoft,
        warningSoft = if (t.isDark) HandyColors.WarningSoftDark else HandyColors.WarningSoftLight,
        sticky = if (t.isDark) HandyColors.StickyDark else HandyColors.StickyLight,
        border = t.border, surfaceRaised = t.surfaceRaised, textSecondary = t.textSecondary, isDark = t.isDark
    )

    // key() tears down + rebuilds the whole tree on a theme (or system-dark) change, so composables
    // that read the HandyColors.Accent var — not just CompositionLocals — re-skin too.
    key(active, systemDark) {
        CompositionLocalProvider(LocalHandy provides palette) {
            MaterialTheme(colorScheme = schemeFor(t), typography = HandyTypography, shapes = HandyShapes) {
                androidx.compose.material3.Surface(color = MaterialTheme.colorScheme.background, contentColor = MaterialTheme.colorScheme.onBackground) { content() }
            }
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
                modifier = Modifier.semantics { contentDescription = label },
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
        // clearAndSetSemantics collapses the chip to one node that actually carries the name + selected
        // state in the accessibility tree (a child-level contentDescription wasn't surfacing, so screen
        // readers — and the QA a11y check — saw an unlabeled checkable control).
        shape = CircleShape, modifier = Modifier.height(HandyTokens.ChipHeight).clearAndSetSemantics { contentDescription = if (selected) "$text, selected" else text },
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
