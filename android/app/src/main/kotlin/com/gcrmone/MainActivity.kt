package com.gcrmone

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "gcrm_notifications"
            val channelName = "GCRM Notifications"
            val channelDescription = "Notifications for memberships, alerts and updates"
            val customSoundId = resources.getIdentifier("notification", "raw", packageName)
            val soundUri = if (customSoundId != 0) {
                Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/$customSoundId")
            } else {
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }

            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = channelDescription
                setSound(soundUri, audioAttributes)
                enableVibration(true)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            val existingChannel = notificationManager?.getNotificationChannel(channelId)
            if (existingChannel != null && existingChannel.sound != soundUri) {
                notificationManager.deleteNotificationChannel(channelId)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }
}
