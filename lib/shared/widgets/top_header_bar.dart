import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/persistence/database_provider.dart';

class TopHeaderBar extends ConsumerWidget {
  final VoidCallback onProfileTap;

  const TopHeaderBar({
    super.key,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(isSyncingPlaylistProvider);
    final syncStatus = ref.watch(playlistSyncStatusProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // Real-time Sync Progress & Status
              if (isSyncing) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  syncStatus ?? 'Syncing channels with IPTV provider...',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),

              // Profile Avatar with dropdown arrow
              InkWell(
                onTap: onProfileTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 1.5),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE50914), Color(0xFFFF5252)],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isSyncing)
          const LinearProgressIndicator(
            minHeight: 2.5,
            backgroundColor: Colors.transparent,
            color: AppColors.primary,
          ),
      ],
    );
  }
}

