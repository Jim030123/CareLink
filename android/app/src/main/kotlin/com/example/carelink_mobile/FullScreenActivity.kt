package com.example.carelink_mobile

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity

class FullScreenActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Set flags to show over lock screen / turn screen on for older APIs
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        setContentView(R.layout.activity_fullscreen)

        // If the notification passed payload extras, you can read them here
        val payload = intent?.getStringExtra("payload")
        // Optionally show payload in UI or log
        payload?.let { android.util.Log.d("FullScreenActivity", "payload=$it") }

        // Dismiss button will finish the activity
        findViewById<View>(R.id.fullscreen_close_button)?.setOnClickListener {
            finish()
        }
    }
}
