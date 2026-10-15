package com.handytools.app.tools.alarm

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.handytools.app.data.Alarm
import kotlin.random.Random

class AlarmRingActivity : ComponentActivity() {

    private val finished = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, i: Intent?) { finish() }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true); setTurnScreenOn(true)
            getSystemService(KeyguardManager::class.java).requestDismissKeyguard(this, null)
        }
        ContextCompat.registerReceiver(this, finished, IntentFilter(AlarmRingService.ACTION_FINISHED), ContextCompat.RECEIVER_NOT_EXPORTED)
        val id = intent.getLongExtra("id", -1)
        val alarm = AlarmRingService.current

        setContent {
            RingScreen(alarm,
                onSnooze = { send(AlarmRingService.ACTION_SNOOZE, id) },
                onDismiss = { send(AlarmRingService.ACTION_DISMISS, id) })
        }
    }

    private fun send(action: String, id: Long) {
        startService(Intent(this, AlarmRingService::class.java).setAction(action).putExtra("id", id))
    }

    override fun onDestroy() { unregisterReceiver(finished); super.onDestroy() }
}

@Composable
private fun RingScreen(a: Alarm?, onSnooze: () -> Unit, onDismiss: () -> Unit) {
    var mathAnswer by remember { mutableStateOf("") }
    val x = remember { Random.nextInt(12, 60) }; val y = remember { Random.nextInt(12, 60) }
    val needMath = a?.mathToDismiss == true
    val snoozesLeft = a?.let { if (it.maxSnoozes == 0) null else it.maxSnoozes - it.snoozedCount }

    Column(
        Modifier.fillMaxSize().background(Color(0xFF0E0E12)).padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center
    ) {
        Text(a?.let { String.format("%02d:%02d", it.hour, it.minute) } ?: "--:--", color = Color.White, fontSize = 88.sp, fontWeight = FontWeight.Light)
        Text(a?.label?.ifBlank { "Alarm" } ?: "Alarm", color = Color(0xFFBBBBBB), fontSize = 22.sp)
        Spacer(Modifier.height(48.dp))
        if (needMath) {
            Text("$x + $y = ?", color = Color.White, fontSize = 32.sp)
            OutlinedTextField(mathAnswer, { mathAnswer = it.filter { c -> c.isDigit() } }, singleLine = true, modifier = Modifier.padding(top = 12.dp))
        }
        Spacer(Modifier.height(24.dp))
        Button(onClick = onDismiss, enabled = !needMath || mathAnswer.toIntOrNull() == x + y, modifier = Modifier.fillMaxWidth().height(64.dp)) {
            Text("Dismiss", fontSize = 20.sp)
        }
        Spacer(Modifier.height(12.dp))
        if (snoozesLeft == null || snoozesLeft > 0) {
            OutlinedButton(onClick = onSnooze, modifier = Modifier.fillMaxWidth().height(56.dp)) {
                Text("Snooze ${a?.snoozeMinutes ?: 9} min" + (snoozesLeft?.let { " ($it left)" } ?: ""), color = Color.White)
            }
        }
    }
}
