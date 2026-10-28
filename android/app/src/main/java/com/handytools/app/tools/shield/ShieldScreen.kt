package com.handytools.app.tools.shield

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.ToolHeader

private val ScamRed = Color(0xFFD92D20)
private val ScamAmber = Color(0xFFB54708)
private val ScamGreen = Color(0xFF127A3E)

private fun verdictColor(v: ScamAnalyzer.Verdict): Color = when (v) {
    ScamAnalyzer.Verdict.LIKELY_SCAM -> ScamRed
    ScamAnalyzer.Verdict.SUSPICIOUS -> ScamAmber
    ScamAnalyzer.Verdict.LOW_RISK -> ScamGreen
}

/**
 * Scam & Safety Check. Paste a suspicious text, email or DM and see, line by line, why it is — or
 * isn't — a scam: the pressure tactics, the payment rail, the look-alike link or sender. Everything
 * runs on the phone; nothing is ever uploaded, and it never reads your messages on its own.
 */
@Composable
fun ShieldScreen() {
    val ctx = LocalContext.current
    val clipboard = LocalClipboardManager.current
    var text by remember { mutableStateOf("") }
    var report by remember { mutableStateOf<ScamAnalyzer.Report?>(null) }

    fun check() {
        if (text.isBlank()) return
        report = ScamAnalyzer.analyze(text)
        HandyHaptics.light(ctx)
    }

    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())
    ) {
        ToolHeader("Scam & Safety Check", "Paste a suspicious message, email or link and see exactly why it's a scam — or why it's fine.")
        Spacer(Modifier.size(16.dp))

        OutlinedTextField(
            value = text,
            onValueChange = { text = it; if (report != null) report = null },
            modifier = Modifier.fillMaxWidth(),
            minLines = 5,
            placeholder = { Text("Paste the text, email, link or number here…") },
        )
        Spacer(Modifier.size(10.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HSecondaryButton("Paste", modifier = Modifier.weight(1f)) {
                clipboard.getText()?.text?.let { text = it; check() }
            }
            if (text.isNotEmpty()) {
                HSecondaryButton("Clear", modifier = Modifier.weight(1f)) { text = ""; report = null }
            }
        }
        Spacer(Modifier.size(10.dp))
        HPrimaryButton("Check it", modifier = Modifier.fillMaxWidth(), enabled = text.isNotBlank()) { check() }

        report?.let { r ->
            Spacer(Modifier.size(20.dp))
            ReportCard(r)
            Spacer(Modifier.size(12.dp))
            HSecondaryButton("Share this check with someone", modifier = Modifier.fillMaxWidth()) {
                Share.text(ctx, shareText(r))
            }
        }

        Spacer(Modifier.size(16.dp))
        Text(
            "Runs entirely on your phone; the message is never sent anywhere, and this tool never reads your texts on its own. A clean result isn't a guarantee — when money or codes are involved, verify through an official channel.",
            color = Handy.palette.textSecondary,
            fontSize = 12.sp,
        )
        Spacer(Modifier.size(16.dp))
        BannerAd()
    }
}

@Composable
private fun ReportCard(r: ScamAnalyzer.Report) {
    val color = verdictColor(r.verdict)
    Column(
        Modifier.fillMaxWidth()
            .padding(0.dp)
    ) {
        // Verdict header: score ring + label
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(contentAlignment = Alignment.Center) {
                CircularProgressIndicator(
                    progress = { r.score / 100f },
                    modifier = Modifier.size(64.dp),
                    color = color,
                    trackColor = Handy.palette.border,
                    strokeWidth = 7.dp,
                )
                Text("${r.score}", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = MaterialTheme.colorScheme.onBackground)
            }
            Spacer(Modifier.size(14.dp))
            Column {
                Text(r.verdict.label, fontWeight = FontWeight.Bold, fontSize = 20.sp, color = color)
                Text(
                    if (r.findings.isEmpty()) "No scam patterns found"
                    else "${r.findings.size} warning sign${if (r.findings.size == 1) "" else "s"}",
                    color = Handy.palette.textSecondary, fontSize = 13.sp,
                )
            }
        }

        // Findings
        r.findings.forEach { finding ->
            Spacer(Modifier.size(14.dp))
            Row {
                Text(
                    if (finding.weight >= 3) "⚠" else "•",
                    color = if (finding.weight >= 3) ScamRed else Handy.palette.textSecondary,
                    fontSize = 15.sp,
                    modifier = Modifier.padding(end = 10.dp),
                )
                Column {
                    Text(finding.title, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
                    Text(finding.detail, color = Handy.palette.textSecondary, fontSize = 13.sp)
                }
            }
        }

        // Links
        if (r.links.isNotEmpty()) {
            Spacer(Modifier.size(16.dp))
            Text("Links", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
            r.links.forEach { link ->
                Spacer(Modifier.size(8.dp))
                SelectionContainer {
                    Text(
                        link.host,
                        fontFamily = FontFamily.Monospace,
                        color = if (link.issues.isEmpty()) MaterialTheme.colorScheme.onBackground else ScamRed,
                        fontSize = 13.sp,
                    )
                }
                Text(
                    if (link.issues.isEmpty()) "No obvious tricks in the address." else link.issues.joinToString(" "),
                    color = Handy.palette.textSecondary, fontSize = 12.sp,
                )
            }
        }

        // Advice
        Spacer(Modifier.size(16.dp))
        Text("What to do", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
        ScamAnalyzer.advice(r).forEach { line ->
            Spacer(Modifier.size(6.dp))
            Row {
                Text("•", color = Handy.palette.textSecondary, modifier = Modifier.padding(end = 10.dp))
                Text(line, color = MaterialTheme.colorScheme.onBackground, fontSize = 14.sp)
            }
        }
    }
}

private fun shareText(r: ScamAnalyzer.Report): String =
    "Scam & Safety Check: ${r.verdict.label} (${r.score}/100)\n" +
        r.findings.joinToString("\n") { "• ${it.title}" } +
        "\n\nChecked with Tenzy."
