import 'package:flutter/material.dart';

import '../../../../core/persistence/app_database.dart';
import '../../../../shared/models/media_item.dart';
import '../domain/device_form_factor.dart';
import 'mobile/mobile_movie_details_sheet.dart';
import 'mobile/mobile_series_details_sheet.dart';
import 'desktop/desktop_movie_details_modal.dart';
import 'desktop/desktop_series_details_modal.dart';
import 'tv/tv_movie_details_page.dart';
import 'tv/tv_series_details_page.dart';
import '../../live_tv/presentation/desktop/desktop_live_tv_preview_modal.dart';
import '../../live_tv/presentation/mobile/mobile_live_tv_preview_sheet.dart';
import '../../live_tv/presentation/tv/tv_live_tv_preview_page.dart';

class AdaptiveDetailsCoordinator {
  /// Opens the device-adaptive details presentation for a given [ContentItemsTableData] or [MediaItem]
  static Future<void> show(
    BuildContext context, {
    ContentItemsTableData? content,
    MediaItem? mediaItem,
  }) async {
    final effectiveContent = content ?? mediaItem?.toContentItem();
    if (effectiveContent == null) return;

    final isLive = effectiveContent.type == 'live';
    final isSeries = effectiveContent.type == 'series';
    final mode = DeviceFormFactor.getPresentationMode(context);

    switch (mode) {
      case DetailsPresentationMode.tvFullScreen:
        // ── Android TV: Dedicated Full-Screen Page with D-pad focus ──
        if (isLive) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TvLiveTvPreviewPage(channel: effectiveContent),
            ),
          );
        } else if (isSeries) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TvSeriesDetailPage(series: effectiveContent),
            ),
          );
        } else {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TvMovieDetailsPage(movie: effectiveContent),
            ),
          );
        }
        break;

      case DetailsPresentationMode.desktopModal:
        // ── Windows & Linux Desktop: Centered Modal Overlay ──
        await showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          barrierColor: Colors.black.withValues(alpha: 0.72),
          transitionDuration: const Duration(milliseconds: 260),
          transitionBuilder: (context, anim, secondaryAnim, child) {
            final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
          pageBuilder: (context, _, __) {
            return Center(
              child: isLive
                  ? DesktopLiveTvPreviewModal(channel: effectiveContent)
                  : (isSeries
                      ? DesktopSeriesDetailsModal(series: effectiveContent)
                      : DesktopMovieDetailsModal(movie: effectiveContent)),
            );
          },
        );
        break;

      case DetailsPresentationMode.mobileBottomSheet:
        // ── Android Mobile: Expandable Modal Bottom Sheet ──
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.65),
          enableDrag: true,
          builder: (ctx) {
            return isLive
                ? MobileLiveTvPreviewSheet(channel: effectiveContent)
                : (isSeries
                    ? MobileSeriesDetailsSheet(series: effectiveContent)
                    : MobileMovieDetailsSheet(movie: effectiveContent));
          },
        );
        break;
    }
  }

  /// Convenience helper for MediaItem
  static Future<void> showMediaItem(BuildContext context, MediaItem item) {
    return show(context, mediaItem: item);
  }
}

