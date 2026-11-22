import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum DetailsPresentationMode {
  mobileBottomSheet,
  desktopModal,
  tvFullScreen,
}

class DeviceFormFactor {
  static const double mobileNavigationBreakpoint = 768;

  /// Manual override for uncertified Android TV boxes / AOSP devices that
  /// report touch mode instead of `NavigationMode.directional`.
  static final ValueNotifier<bool> forceTvMode = ValueNotifier<bool>(false);

  /// Detected natively on Android via `FEATURE_LEANBACK` or
  /// `UI_MODE_TYPE_TELEVISION` so real Android TVs / Google TVs always get the
  /// TV interface even when they report `NavigationMode.traditional`.
  static bool nativeAndroidTv = false;

  /// Detects Android TV by native Leanback/TV UI mode, directional navigation,
  /// or manual Force TV Mode override — never by screen size alone.
  static bool isTv(BuildContext context) {
    if (forceTvMode.value || nativeAndroidTv) return true;
    return defaultTargetPlatform == TargetPlatform.android &&
        MediaQuery.of(context).navigationMode == NavigationMode.directional;
  }

  /// Desktop classification follows the runtime platform; window size stays a
  /// responsive-layout concern and cannot turn a phone into a desktop.
  static bool isDesktop(BuildContext context) {
    if (isTv(context)) return false;

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return true;
    }

    return kIsWeb && MediaQuery.of(context).size.width >= 1024;
  }

  /// Handheld platforms include phones and tablets; their layout may still
  /// respond to available width independently.
  static bool isMobile(BuildContext context) {
    return !isTv(context) && !isDesktop(context);
  }

  /// Selects the appropriate presentation mode
  static DetailsPresentationMode getPresentationMode(BuildContext context) {
    if (isTv(context)) {
      return DetailsPresentationMode.tvFullScreen;
    }

    final width = MediaQuery.of(context).size.width;

    if (isDesktop(context)) {
      // If a desktop window is resized to a phone-like narrow width (< 720px), use bottom sheet
      if (width < 720) {
        return DetailsPresentationMode.mobileBottomSheet;
      }
      return DetailsPresentationMode.desktopModal;
    }

    // Mobile / Handheld devices
    if (width < 768) {
      return DetailsPresentationMode.mobileBottomSheet;
    }

    // Tablet landscape can use desktop modal for a spacious experience
    return DetailsPresentationMode.desktopModal;
  }
}
