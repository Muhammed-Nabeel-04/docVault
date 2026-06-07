package com.nabeel.docvault

import io.flutter.embedding.android.FlutterFragmentActivity
import android.view.WindowManager

class MainActivity: FlutterFragmentActivity() {
    override fun onResume() {
        super.onResume()
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
