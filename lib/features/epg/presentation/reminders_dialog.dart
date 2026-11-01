import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/media_item.dart';
import '../../player/data/player_controller.dart';
import '../data/program_reminder_service.dart';

class RemindersDialog extends ConsumerWidget {
  const RemindersDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const RemindersDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(activeRemindersProvider);
    final service = ref.read(programReminderServiceProvider);
    final player = ref.read(playerControllerProvider.notifier);
    final timeFormat = DateFormat.jm();
    final dateFormat = DateFormat('EEE, MMM d');

    return Dialog(
      backgroundColor: const Color(0xFF16161C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.alarm_on_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Programme Reminders',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${reminders.length} scheduled reminders',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Reminders list
            if (reminders.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 56, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      const Text(
                        'No Reminders Set',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Browse Live TV and select upcoming programmes to set reminders.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: reminders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = reminders[index];
                    final startLocal = item.startTime.toLocal();
                    final stopLocal = item.stopTime.toLocal();

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          // Channel logo
                          if (item.channelLogo != null && item.channelLogo!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: item.channelLogo!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => _channelFallback(item.channelName),
                              ),
                            )
                          else
                            _channelFallback(item.channelName),

                          const SizedBox(width: 14),

                          // Programme Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.programTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.channelName,
                                  style: TextStyle(
                                    color: AppColors.primary.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${dateFormat.format(startLocal)} • ${timeFormat.format(startLocal)} – ${timeFormat.format(stopLocal)} (${item.leadMinutes}m before)',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Tune In button if streamUrl is available
                          if (item.streamUrl != null && item.streamUrl!.isNotEmpty) ...[
                            IconButton(
                              tooltip: 'Tune In Now',
                              icon: const Icon(Icons.play_circle_fill_rounded,
                                  color: AppColors.primary, size: 26),
                              onPressed: () {
                                final media = MediaItem(
                                  id: item.channelId,
                                  title: item.channelName,
                                  type: MediaType.live,
                                  posterUrl: item.channelLogo,
                                  streamUrl: item.streamUrl,
                                );
                                Navigator.of(context).pop();
                                player.playItem(media, startFullscreen: true);
                              },
                            ),
                          ],

                          // Cancel Reminder button
                          IconButton(
                            tooltip: 'Cancel Reminder',
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 20),
                            onPressed: () => service.removeReminder(item.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _channelFallback(String name) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

class SetReminderHelper {
  static Future<void> prompt(
    BuildContext context, {
    required WidgetRef ref,
    required String channelId,
    required String channelName,
    String? channelLogo,
    String? streamUrl,
    required String programTitle,
    String? programDescription,
    required DateTime start,
    required DateTime stop,
  }) async {
    final service = ref.read(programReminderServiceProvider);
    final isAlreadySet = service.isReminderSet(programTitle, channelId, start);

    if (isAlreadySet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A reminder is already set for "$programTitle"'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    int selectedLead = 5;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          title: const Row(
            children: [
              Icon(Icons.alarm_add_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text('Set Programme Reminder', style: TextStyle(color: Colors.white, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                programTitle,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                channelName,
                style: const TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                'Notify me before start:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [5, 10, 15].map((mins) {
                  final isSel = selectedLead == mins;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$mins mins'),
                      selected: isSel,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setDialogState(() => selectedLead = mins),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Set Reminder'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      final reminder = ProgramReminder(
        id: '${channelId}_${start.millisecondsSinceEpoch}',
        channelId: channelId,
        channelName: channelName,
        channelLogo: channelLogo,
        streamUrl: streamUrl,
        programTitle: programTitle,
        programDescription: programDescription,
        startTime: start,
        stopTime: stop,
        leadMinutes: selectedLead,
      );

      final added = await service.addReminder(reminder);
      if (added && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text('Reminder set for "$programTitle" ($selectedLead mins before)'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
