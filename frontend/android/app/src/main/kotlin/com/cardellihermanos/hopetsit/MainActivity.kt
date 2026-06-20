package com.cardellihermanos.hopetsit

import io.flutter.embedding.android.FlutterFragmentActivity

// v498 — package renommé com.hopetsit.app -> com.cardellihermanos.hopetsit
// (exigence Google Play). On conserve FlutterFragmentActivity (requis par
// image_picker / local_auth qui ont besoin d'une FragmentActivity).
class MainActivity : FlutterFragmentActivity()
