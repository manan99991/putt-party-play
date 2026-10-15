package com.handytools.app.ui

import android.app.Activity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.HandyApp

@Composable
fun PaywallScreen(onBack: () -> Unit) {
    val billing = HandyApp.instance.billing
    val premium by billing.isPremium.collectAsState()
    val product by billing.product.collectAsState()
    val activity = LocalContext.current as Activity

    Column(
        Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Text("HandyTools Pro", style = MaterialTheme.typography.headlineLarge)
        Spacer(Modifier.height(8.dp))
        Text("One yearly payment. Ads gone for good.", style = MaterialTheme.typography.bodyLarge)
        Spacer(Modifier.height(24.dp))
        listOf(
            "No banner or full-screen ads",
            "Unlimited clipboard history (free: last 20)",
            "Unlimited alarms (free: 3)",
            "Support one indie developer"
        ).forEach {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 6.dp)) {
                Icon(Icons.Default.Check, null, tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(12.dp))
                Text(it)
            }
        }
        Spacer(Modifier.height(32.dp))
        if (premium) {
            Text("You're Pro. Thank you.", style = MaterialTheme.typography.titleMedium)
        } else {
            Button(
                onClick = { billing.launchPurchase(activity) },
                enabled = product != null,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(if (product == null) "Loading price…" else "Go Pro · ${billing.priceLabel}")
            }
            Text(
                "Auto-renews yearly. Cancel anytime in Google Play.",
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
        Spacer(Modifier.height(16.dp))
        TextButton(onClick = onBack) { Text("Not now") }
    }
}
