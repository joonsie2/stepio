package io.stepio.health

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

/** Shown by Health Connect when the player asks why step.io wants step data. */
class PrivacyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val padding = (24 * resources.displayMetrics.density).toInt()
        setContentView(TextView(this).apply {
            setText(R.string.stepio_health_privacy)
            setPadding(padding, padding, padding, padding)
        })
    }
}
