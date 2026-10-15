package com.handytools.app.tools.quick

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast

object QuickActions {

    @Volatile var torchOn = false
        private set

    private fun torchCameraId(cm: CameraManager): String? =
        cm.cameraIdList.firstOrNull { id ->
            val c = cm.getCameraCharacteristics(id)
            c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                c.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        }

    fun toggleFlashlight(ctx: Context): Boolean {
        val cm = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = torchCameraId(cm) ?: run { Toast.makeText(ctx, "No flash on this device", Toast.LENGTH_SHORT).show(); return false }
        torchOn = !torchOn
        runCatching { cm.setTorchMode(id, torchOn) }.onFailure { torchOn = false }
        return torchOn
    }

    /** Android 13+ exposes torch strength on supported phones. 0 = use max. */
    fun setFlashlightLevel(ctx: Context, level: Int) {
        if (Build.VERSION.SDK_INT < 33) return
        val cm = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = torchCameraId(cm) ?: return
        val max = cm.getCameraCharacteristics(id).get(CameraCharacteristics.FLASH_INFO_STRENGTH_MAXIMUM_LEVEL) ?: 1
        if (max <= 1) return
        runCatching { cm.turnOnTorchWithStrengthLevel(id, level.coerceIn(1, max)); torchOn = true }
    }

    fun flashlightMaxLevel(ctx: Context): Int {
        if (Build.VERSION.SDK_INT < 33) return 1
        val cm = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = torchCameraId(cm) ?: return 1
        return cm.getCameraCharacteristics(id).get(CameraCharacteristics.FLASH_INFO_STRENGTH_MAXIMUM_LEVEL) ?: 1
    }

    /**
     * Android 8+ removed the public API to toggle the hotspot. The fastest legal path is the
     * tethering settings page (one tap away). On Samsung/Pixel this deep-links straight to it.
     */
    fun openHotspot(ctx: Context) {
        val i = Intent(Intent.ACTION_MAIN).setClassName("com.android.settings", "com.android.settings.TetherSettings")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { ctx.startActivity(i) }.onFailure {
            ctx.startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    fun openCamera(ctx: Context) {
        ctx.startActivity(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun openVideo(ctx: Context) {
        ctx.startActivity(Intent(MediaStore.INTENT_ACTION_VIDEO_CAMERA).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun openSelfie(ctx: Context) {
        ctx.startActivity(
            Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
                .putExtra("android.intent.extras.CAMERA_FACING", 1)
                .putExtra("android.intent.extras.LENS_FACING_FRONT", 1)
                .putExtra("android.intent.extra.USE_FRONT_CAMERA", true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }
}

/** Quick Settings tile so the flashlight is also one swipe away. */
class FlashlightTileService : TileService() {
    override fun onStartListening() { qsTile?.state = if (QuickActions.torchOn) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE; qsTile?.updateTile() }
    override fun onClick() {
        val on = QuickActions.toggleFlashlight(this)
        qsTile?.state = if (on) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        qsTile?.updateTile()
    }
}
