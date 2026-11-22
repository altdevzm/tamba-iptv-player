import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/player_controller.dart';
import '../../domain/playback_enums.dart';
import '../../streaming/streaming_models.dart';
import '../../tiss/tiss_models.dart';

/// Technical diagnostics panel accessible from the player controls.
/// Shows decoder type, HW acceleration, resolution, bitrate, buffer, etc.
class PlaybackDiagnosticsPanel extends ConsumerStatefulWidget {
  const PlaybackDiagnosticsPanel({super.key});

  @override
  ConsumerState<PlaybackDiagnosticsPanel> createState() =>
      _PlaybackDiagnosticsPanelState();
}

class _PlaybackDiagnosticsPanelState
    extends ConsumerState<PlaybackDiagnosticsPanel> {
  Map<String, String> _diagnostics = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final controller = ref.read(playerControllerProvider.notifier);
    try {
      final diag = await controller.getDiagnostics();
      if (mounted) {
        setState(() {
          _diagnostics = diag;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final panelWidth =
        (MediaQuery.of(context).size.width - 32).clamp(260.0, 340.0).toDouble();

    return Container(
      width: panelWidth,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Playback Diagnostics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                GestureDetector(
                  onTap: _refresh,
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          _DiagRow(
            icon: Icons.memory_rounded,
            label: 'Decoder',
            value: _diagnostics['decoder'] ?? 'detecting...',
            valueColor: _isHWDecoder(_diagnostics['decoder'])
                ? Colors.greenAccent
                : Colors.white70,
          ),
          _DiagRow(
            icon: Icons.hardware_rounded,
            label: 'HW Acceleration',
            value: _isHWDecoder(_diagnostics['decoder'])
                ? '✓ Active'
                : '✗ Software',
            valueColor: _isHWDecoder(_diagnostics['decoder'])
                ? Colors.greenAccent
                : Colors.orangeAccent,
          ),
          _DiagRow(
            icon: Icons.aspect_ratio_rounded,
            label: 'Resolution',
            value: _diagnostics['resolution'] ?? 'unknown',
          ),
          _DiagRow(
            icon: Icons.speed_rounded,
            label: 'Frame Rate',
            value: _diagnostics['fps'] ?? 'unknown',
          ),
          if (_diagnostics['video_codec'] != null)
            _DiagRow(
              icon: Icons.movie_filter_outlined,
              label: 'Video Codec',
              value: _diagnostics['video_codec']!,
            ),
          _DiagRow(
            icon: Icons.audiotrack_rounded,
            label: 'Audio Format',
            value: _diagnostics['audio_codec'] ??
                _diagnostics['audio_format'] ??
                'unknown',
          ),
          if (_diagnostics['bitrate'] != null)
            _DiagRow(
              icon: Icons.network_check_rounded,
              label: 'Bitrate',
              value: _diagnostics['bitrate']!,
            ),
          _DiagRow(
            icon: Icons.hourglass_bottom_rounded,
            label: 'Buffer',
            value: '${playerState.bufferDuration.inSeconds}s',
          ),
          _DiagRow(
            icon: Icons.timer_outlined,
            label: 'Startup (TTFF)',
            value: _diagnostics['ttff'] ?? 'measuring...',
          ),
          if (_diagnostics['avg_startup'] != null &&
              _diagnostics['avg_startup'] != 'n/a')
            _DiagRow(
              icon: Icons.av_timer_rounded,
              label: 'Avg Startup',
              value: _diagnostics['avg_startup']!,
            ),
          if (_diagnostics['channel_switch'] != null)
            _DiagRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Channel Switch',
              value: _diagnostics['channel_switch']!,
            ),
          _DiagRow(
            icon: Icons.sync_problem_rounded,
            label: 'Rebuffers',
            value:
                '${_diagnostics['rebuffer_count'] ?? '0'} (${_diagnostics['buffering_total'] ?? '0.0s'})',
            valueColor: (int.tryParse(_diagnostics['rebuffer_count'] ?? '0') ?? 0) >= 3
                ? Colors.orangeAccent
                : Colors.white70,
          ),
          _DiagRow(
            icon: Icons.broken_image_outlined,
            label: 'Dropped Frames',
            value: _diagnostics['dropped_frames'] ?? '0',
            valueColor: (int.tryParse(_diagnostics['dropped_frames'] ?? '0') ?? 0) > 60
                ? Colors.orangeAccent
                : Colors.white70,
          ),
          if (_diagnostics['throughput'] != null)
            _DiagRow(
              icon: Icons.speed_rounded,
              label: 'Throughput',
              value: _diagnostics['throughput']!,
            ),
          _DiagRow(
            icon: Icons.play_circle_outline_rounded,
            label: 'State',
            value: playerState.playbackState.displayLabel,
            valueColor: _stateColor(playerState.playbackState.name),
          ),
          _DiagRow(
            icon: Icons.wifi_rounded,
            label: 'Recovery',
            value: _diagnostics['recovery_rate'] ??
                '${playerState.reconnectAttempt} / 5',
            valueColor: playerState.reconnectAttempt > 0
                ? Colors.orangeAccent
                : Colors.white70,
          ),
          if (_diagnostics['root_cause'] != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                _diagnostics['root_cause']!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white38, size: 15),
                const SizedBox(width: 8),
                const Text(
                  'Buffer profile',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                DropdownButtonHideUnderline(
                  child: DropdownButton<BufferProfile>(
                    value: ref.read(playerControllerProvider.notifier).bufferProfile,
                    dropdownColor: const Color(0xFF202027),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    items: BufferProfile.values
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.label),
                          ),
                        )
                        .toList(),
                    onChanged: (profile) {
                      if (profile != null) {
                        ref
                            .read(playerControllerProvider.notifier)
                            .setBufferProfile(profile);
                        _refresh();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (ref.read(playerControllerProvider.notifier).availableRenditions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(Icons.hd_rounded, color: Colors.white38, size: 15),
                  const SizedBox(width: 8),
                  const Text(
                    'Quality (ABR)',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<StreamRendition>(
                      value: ref
                          .read(playerControllerProvider.notifier)
                          .selectedRendition,
                      dropdownColor: const Color(0xFF202027),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      items: ref
                          .read(playerControllerProvider.notifier)
                          .availableRenditions
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ),
                          )
                          .toList(),
                      onChanged: (rendition) {
                        if (rendition != null) {
                          ref
                              .read(playerControllerProvider.notifier)
                              .selectQuality(rendition);
                          _refresh();
                        }
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            _DiagRow(
              icon: Icons.hd_outlined,
              label: 'Quality',
              value: _diagnostics['quality'] ?? 'Fixed quality (ABR N/A)',
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                const Icon(Icons.live_tv_rounded,
                    color: Colors.white38, size: 15),
                const SizedBox(width: 8),
                const Text(
                  'Live format',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                DropdownButtonHideUnderline(
                  child: DropdownButton<LiveStreamFormat>(
                    value: playerState.liveStreamFormat,
                    dropdownColor: const Color(0xFF202027),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    items: const [
                      DropdownMenuItem(
                        value: LiveStreamFormat.providerDefault,
                        child: Text('Default'),
                      ),
                      DropdownMenuItem(
                        value: LiveStreamFormat.ts,
                        child: Text('TS'),
                      ),
                      DropdownMenuItem(
                        value: LiveStreamFormat.hls,
                        child: Text('HLS'),
                      ),
                    ],
                    onChanged: (format) {
                      if (format != null) {
                        ref
                            .read(playerControllerProvider.notifier)
                            .setLiveStreamFormat(format);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (playerState.currentItem?.streamUrl != null)
            _DiagRow(
              icon: Icons.link_rounded,
              label: 'Stream Type',
              value: _detectStreamType(playerState.currentItem!.streamUrl!),
            ),
          ..._buildTissSection(ref),
        ],
      ),
      ),
    );
  }

  List<Widget> _buildTissSection(WidgetRef ref) {
    final controller = ref.read(playerControllerProvider.notifier);
    final tiss = controller.tissController;
    final snap = tiss.diagnosticsSnapshot();
    final channel = tiss.activeChannel;

    return [
      const SizedBox(height: 10),
      const Divider(color: Colors.white12, height: 1),
      const SizedBox(height: 10),
      const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 15),
          SizedBox(width: 6),
          Text(
            'Tamba SmartStream (TISS)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.auto_mode_rounded,
                color: Colors.white38, size: 15),
            const SizedBox(width: 8),
            const Text(
              'SmartStream Mode',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Spacer(),
            DropdownButtonHideUnderline(
              child: DropdownButton<SmartStreamMode>(
                value: controller.smartStreamMode,
                dropdownColor: const Color(0xFF202027),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                items: SmartStreamMode.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.label),
                      ),
                    )
                    .toList(),
                onChanged: (mode) {
                  if (mode != null) {
                    controller.setSmartStreamMode(mode);
                    setState(() {});
                  }
                },
              ),
            ),
          ],
        ),
      ),
      if (snap.logicalChannelName != null)
        _DiagRow(
          icon: Icons.tv_rounded,
          label: 'Logical Channel',
          value: snap.logicalChannelName!,
        ),
      if (snap.activeStreamRedactedId != null)
        _DiagRow(
          icon: Icons.shield_outlined,
          label: 'Active Stream',
          value: snap.activeStreamRedactedId!,
        ),
      if (channel != null && channel.alternatives.length > 1)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.high_quality_rounded,
                  color: Colors.white38, size: 15),
              const SizedBox(width: 8),
              const Text(
                'Channel Quality',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: snap.isAutoMode
                      ? '__auto__'
                      : (tiss.activeStream?.streamId ?? '__auto__'),
                  dropdownColor: const Color(0xFF202027),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  items: [
                    const DropdownMenuItem(
                      value: '__auto__',
                      child: Text('Auto (TISS)'),
                    ),
                    ...channel.alternatives.map(
                      (alt) => DropdownMenuItem(
                        value: alt.streamId,
                        child: Text(alt.qualityMenuLabel),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null || val == '__auto__') {
                      controller.selectTissQuality(null);
                    } else {
                      final target = channel.alternatives
                          .firstWhere((a) => a.streamId == val);
                      controller.selectTissQuality(target);
                    }
                    _refresh();
                  },
                ),
              ),
            ],
          ),
        ),
      if (snap.availableQualities.isNotEmpty)
        _DiagRow(
          icon: Icons.layers_outlined,
          label: 'Alternatives',
          value: snap.availableQualities.join(', '),
        ),
      if (snap.failedQualities.isNotEmpty)
        _DiagRow(
          icon: Icons.warning_amber_rounded,
          label: 'Failed Alts',
          value: snap.failedQualities.join(', '),
          valueColor: Colors.orangeAccent,
        ),
      if (snap.lastFailoverEvent != null)
        _DiagRow(
          icon: Icons.swap_calls_rounded,
          label: 'Last Failover',
          value: snap.lastFailoverEvent!.summary,
        ),
      _DiagRow(
        icon: Icons.verified_outlined,
        label: 'TISS Recoveries',
        value: '${snap.successfulRecoveries}',
        valueColor:
            snap.successfulRecoveries > 0 ? Colors.greenAccent : Colors.white70,
      ),
      SwitchListTile.adaptive(
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppColors.primary,
        title: const Text(
          'Auto Quality Upgrade',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        value: snap.autoUpgradeEnabled,
        onChanged: (v) {
          controller.toggleTissAutoUpgrade(v);
          setState(() {});
        },
      ),
      SwitchListTile.adaptive(
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeThumbColor: Colors.orangeAccent,
        title: const Text(
          'Simulate Poor Network (Dev)',
          style: TextStyle(color: Colors.white54, fontSize: 11.5),
        ),
        value: snap.simulatePoorNetwork,
        onChanged: (v) {
          controller.toggleTissSimulatePoorNetwork(v);
          setState(() {});
        },
      ),
    ];
  }

  bool _isHWDecoder(String? decoder) {
    if (decoder == null || decoder.isEmpty) return false;
    return decoder != 'no' &&
        decoder != 'software' &&
        decoder != 'unknown' &&
        decoder != 'detecting...';
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'playing':
        return Colors.greenAccent;
      case 'buffering':
        return Colors.amberAccent;
      case 'reconnecting':
        return Colors.orangeAccent;
      case 'failed':
        return Colors.redAccent;
      case 'paused':
        return Colors.white70;
      default:
        return Colors.white54;
    }
  }

  String _detectStreamType(String url) {
    if (url.contains('.m3u8')) return 'HLS (.m3u8)';
    if (url.contains('.ts')) return 'MPEG-TS (.ts)';
    if (url.contains('.mpd')) return 'MPEG-DASH (.mpd)';
    if (url.contains('.mp4')) return 'MP4';
    if (url.contains('.mkv')) return 'MKV';
    return 'IPTV Stream';
  }
}

class _DiagRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DiagRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 15),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
