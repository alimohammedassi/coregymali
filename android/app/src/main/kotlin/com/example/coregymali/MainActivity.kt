package com.example.coregymali

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity): the health plugin's
// registration casts the host activity to androidx.activity.ComponentActivity
// and crashed with ClassCastException under FlutterActivity, which killed
// plugin registration and every Health Connect read.
class MainActivity : FlutterFragmentActivity()
