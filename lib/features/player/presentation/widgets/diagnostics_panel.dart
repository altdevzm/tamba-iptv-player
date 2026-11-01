import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/player_controller.dart';
import '../../domain/playback_enums.dart';

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
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
            icon: Icons.play_circle_outline_rounded,
            label: 'State',
            value: playerState.playbackState.name,
            valueColor: _stateColor(playerState.playbackState.name),
          ),
          _DiagRow(
            icon: Icons.wifi_rounded,
            label: 'Reconnect Attempts',
            value: '${playerState.reconnectAttempt} / 5',
            valueColor: playerState.reconnectAttempt > 0
                ? Colors.orangeAccent
                : Colors.white70,
          ),
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
                  child: DropdownButton<PlaybackProfile>(
                    value: playerState.playbackProfile,
                    dropdownColor: const Color(0xFF202027),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    items: const [
                      DropdownMenuItem(
                        value: PlaybackProfile.auto,
                        child: Text('Balanced'),
                      ),
                      DropdownMenuItem(
                        value: PlaybackProfile.dataSaver,
                        child: Text('Data saver'),
                      ),
                      DropdownMenuItem(
                        value: PlaybackProfile.moreStable,
                        child: Text('More stable'),
                      ),
                      DropdownMenuItem(
                        value: PlaybackProfile.highQuality,
                        child: Text('High quality'),
                      ),
                    ],
                    onChanged: (profile) {
                      if (profile != null) {
                        ref
                            .read(playerControllerProvider.notifier)
                            .setPlaybackProfile(profile);
                      }
                    },
                  ),
                ),
              ],
            ),
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
        ],
      ),
    );
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
