import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Live camera preview is only supported on Android/iOS in this MVP.
bool get supportsLiveCamera {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}
