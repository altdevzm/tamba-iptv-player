import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/persistence/app_database.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../../../shared/widgets/tv_text_field.dart';
import '../../content_details/domain/device_form_factor.dart';
import '../../epg/presentation/epg_notifier.dart';
import '../../player/data/libvlc_bridge.dart';
import '../../player/data/player_controller.dart';
import '../../player/domain/playback_enums.dart';
import '../../player/tiss/tiss_models.dart';
import '../../../shared/services/tmdb_service.dart';
import '../data/backup_service.dart';
import '../../remote_control/data/remote_control_server.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final _epgUrlController = TextEditingController();
  final _tmdbKeyController = TextEditingController();
  final _userAgentController = TextEditingController();
  final _refererController = TextEditingController();
  bool _epgLoading = false;
  String? _epgError;
  String _selectedLanguage = 'en-US';
  String _selectedCountry = 'US';

  static const _languages = {
    'en-US': 'English (US)',
    'en-GB': 'English (UK)',
    'es-ES': 'Spanish (Español)',
    'fr-FR': 'French (Français)',
    'de-DE': 'German (Deutsch)',
    'it-IT': 'Italian (Italiano)',
    'pt-BR': 'Portuguese (Português)',
    'ar-SA': 'Arabic (العربية)',
    'ru-RU': 'Russian (Русский)',
  };

  static const _countries = {
    'US': 'United States (MPAA / TV-MA)',
    'GB': 'United Kingdom (BBFC)',
    'DE': 'Germany (FSK)',
    'FR': 'France (CNC)',
    'ES': 'Spain (ICAA)',
    'CA': 'Canada (CHVRS)',
    'AU': 'Australia (ACB)',
  };

  @override
  void initState() {
    super.initState();
    _loadTmdbSettings();
  }

  Future<void> _loadTmdbSettings() async {
    final tmdb = ref.read(tmdbServiceProvider);
    final storage = ref.read(secureStorageProvider);
    final key = await tmdb.getApiKey();
    final lang = await tmdb.getLanguage();
    final country = await tmdb.getCertificationCountry();
    final ua = await storage.getPlaylistCredentials('filimu_custom_user_agent');
    final refHeader =
        await storage.getPlaylistCredentials('filimu_custom_referer');

    if (mounted) {
      if (key != null) _tmdbKeyController.text = key;
      if (ua != null) _userAgentController.text = ua;
      if (refHeader != null) _refererController.text = refHeader;
      setState(() {
        _selectedLanguage = lang;
        _selectedCountry = country;
      });
    }
  }

  @override
  void dispose() {
    _epgUrlController.dispose();
    _tmdbKeyController.dispose();
    _userAgentController.dispose();
    _refererController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 16 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure your Tamba IPTV experience',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),

            const SizedBox(height: 32),

            // ── My Playlists & Providers Section ──
            _buildSectionHeader('My Playlists & IPTV Providers'),
            const SizedBox(height: 14),
            _buildPlaylistsCard(context),
            const SizedBox(height: 32),

            // ── Display & Smart TV Mode Section ──
            _buildSectionHeader('Display & Smart TV Interface'),
            const SizedBox(height: 14),
            GlassContainer(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              borderRadius: 16,
              child: Material(
                type: MaterialType.transparency,
                child: ValueListenableBuilder<bool>(
                  valueListenable: DeviceFormFactor.forceTvMode,
                  builder: (context, forcedTv, _) {
                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor:
                          AppColors.primary.withValues(alpha: 0.4),
                      title: const Text(
                        'Force Smart TV Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Use the 10-foot TV sidebar, D-pad focus navigation, and full-screen TV details. Ideal for uncertified Android TV boxes or tablets.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                      value: forcedTv,
                      onChanged: (enabled) async {
                        DeviceFormFactor.forceTvMode.value = enabled;
                        try {
                          await ref
                              .read(secureStorageProvider)
                              .savePlaylistCredentials(
                                'filimu_force_tv_mode',
                                enabled ? 'true' : 'false',
                              );
                        } catch (_) {}
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Auto Quality Intelligence ──
            _buildSectionHeader('Auto Quality Intelligence'),
            const SizedBox(height: 14),
            GlassContainer(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              borderRadius: 16,
              child: Material(
                type: MaterialType.transparency,
                child: Builder(
                  builder: (context) {
                    ref.watch(playerControllerProvider);
                    final ctrl = ref.read(playerControllerProvider.notifier);
                    final autoSwitch = ctrl.automaticSwitchingEnabled;
                    final autoUpgrade = ctrl.autoUpgradeEnabled;
                    final pref = ctrl.smartStreamMode;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.primary,
                          activeTrackColor:
                              AppColors.primary.withValues(alpha: 0.4),
                          title: const Text(
                            'Automatic switching',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'Automatically switch to a sustainable quality alternative when a stream buffers or fails.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                          value: autoSwitch,
                          onChanged: (v) => ctrl.setAutomaticSwitching(v),
                        ),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                          height: 16,
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.primary,
                          activeTrackColor:
                              AppColors.primary.withValues(alpha: 0.4),
                          title: const Text(
                            'Automatic upgrades',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'Gradually restore higher video quality once your connection stabilizes.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                          value: autoUpgrade,
                          onChanged: autoSwitch
                              ? (v) => ctrl.toggleTissAutoUpgrade(v)
                              : null,
                        ),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                          height: 20,
                        ),
                        Text(
                          'Preference',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: SmartStreamMode.values.map((mode) {
                            final selected = pref == mode;
                            return ChoiceChip(
                              label: Text(mode.label),
                              selected: selected,
                              onSelected: (_) => ctrl.setSmartStreamMode(mode),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 12.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pref.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // EPG / XMLTV Section
            _buildSectionHeader('Electronic Programme Guide (EPG)'),
            const SizedBox(height: 14),
            GlassContainer(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'XMLTV EPG Source URL',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Provide the URL of your XMLTV-format EPG data (supports .xml and .xml.gz)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isMobile) ...[
                    _buildTextField(
                      _epgUrlController,
                      'EPG URL',
                      'https://example.com/epg.xml.gz',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _epgLoading ? null : _importEpg,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _epgLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Import EPG'),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _epgUrlController,
                            'EPG URL',
                            'https://example.com/epg.xml.gz',
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _epgLoading ? null : _importEpg,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _epgLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Import EPG'),
                        ),
                      ],
                    ),
                  if (_epgError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _epgError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // TMDB Section
            _buildSectionHeader('Metadata Enrichment (TMDB)'),
            const SizedBox(height: 14),
            GlassContainer(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Movie Database (TMDB) API Key',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Optional: Supply your personal TMDB v3 API key to automatically fetch 4K posters, backdrops, and movie synopsis.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isMobile) ...[
                    _buildTextField(
                      _tmdbKeyController,
                      'TMDB API Key',
                      'Enter your 32-character TMDB v3 API Key',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveTmdbKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Save Key'),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _tmdbKeyController,
                            'TMDB API Key',
                            'Enter your 32-character TMDB v3 API Key',
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _saveTmdbKey,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Save Key'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  if (isMobile) ...[
                    _buildLanguageDropdown(),
                    const SizedBox(height: 14),
                    _buildCountryDropdown(),
                  ] else
                    Row(
                      children: [
                        Expanded(child: _buildLanguageDropdown()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildCountryDropdown()),
                      ],
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'Attribution: This product uses the TMDB API but is not endorsed or certified by TMDB.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Playback Section
            _buildSectionHeader('Playback'),
            const SizedBox(height: 14),
            GlassContainer(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (LibVlcBridge.isSupported) ...[
                    _buildPlaybackEngineSelector(),
                    _buildDivider(),
                  ],
                  _buildSwitchRow(
                    'Auto-Resume',
                    'Resume playback from where you left off',
                    true,
                    (v) {},
                  ),
                  _buildDivider(),
                  _buildSwitchRow(
                    'Hardware Acceleration',
                    'Use GPU for video decoding (recommended)',
                    true,
                    (v) {},
                  ),
                  _buildDivider(),
                  _buildSwitchRow(
                    'Auto-Play Next Episode',
                    'Automatically play the next episode in a series',
                    true,
                    (v) {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Data Management Section
            _buildSectionHeader('Data Management & Backup'),
            const SizedBox(height: 14),
            GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 16,
              child: Column(
                children: [
                  _buildActionRow(
                    'Export Backup (.json)',
                    'Save playlists, favorites, and settings to your Downloads folder',
                    Icons.upload_file_rounded,
                    _exportBackup,
                  ),
                  _buildDivider(),
                  _buildActionRow(
                    'Restore from Backup (.json)',
                    'Select a backup .json file from Downloads to restore your setup',
                    Icons.file_download_rounded,
                    _importBackup,
                  ),
                  _buildDivider(),
                  _buildActionRow(
                    'Clear Watch History',
                    'Remove all recently watched entries',
                    Icons.history_rounded,
                    _clearWatchHistory,
                  ),
                  _buildDivider(),
                  _buildActionRow(
                    'Clear EPG Cache',
                    'Delete all stored programme guide data',
                    Icons.tv_off_rounded,
                    _clearEpgCache,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Remote Control & Connectivity Section
            _buildSectionHeader('Remote Control & Mobile Access'),
            const SizedBox(height: 14),
            GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Embedded Web Remote Controller',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Control playback from any smartphone or tablet on the same Wi-Fi network.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (isMobile) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const SelectableText(
                        'http://localhost:8383',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showQrCodeDialog,
                        icon: const Icon(Icons.qr_code_rounded, size: 18),
                        label: const Text('Show QR Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: const SelectableText(
                              'http://localhost:8383',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _showQrCodeDialog,
                          icon: const Icon(Icons.qr_code_rounded, size: 18),
                          label: const Text('Show QR Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Network Headers Section
            _buildSectionHeader('Network & Stream Headers'),
            const SizedBox(height: 14),
            GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Custom HTTP Stream Headers',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Override User-Agent and Referer sent to IPTV streams and EPG providers.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_userAgentController, 'Global User-Agent',
                      'e.g. VLC/3.0.18 LibVLC/3.0.18'),
                  const SizedBox(height: 12),
                  _buildTextField(_refererController, 'Global HTTP Referer',
                      'e.g. https://provider.domain/'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveCustomHeaders,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Stream Headers'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader('About'),
            const SizedBox(height: 14),
            GlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 16,
              child: Column(
                children: [
                  _buildInfoRow('Application', 'Tamba IPTV'),
                  _buildDivider(),
                  _buildInfoRow('Version', '1.0.13'),
                  _buildDivider(),
                  _buildInfoRow('Built With', 'Flutter + Dart'),
                  _buildDivider(),
                  _buildInfoRow(
                    'Media Engine',
                    LibVlcBridge.isSupported
                        ? 'libmpv (media_kit) + LibVLC 3.6 (LGPL v2.1)'
                        : 'libmpv via media_kit',
                  ),
                  _buildDivider(),
                  _buildActionRow(
                    'Open-source disclaimer',
                    'Content sources are supplied and managed by users.',
                    Icons.gavel_rounded,
                    () => context.go('/disclaimer'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTmdbKey() async {
    final messenger = ScaffoldMessenger.of(context);
    final key = _tmdbKeyController.text.trim();
    final tmdb = ref.read(tmdbServiceProvider);
    await tmdb.saveApiKey(key);
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('TMDB API Key saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildLanguageDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metadata Language',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _languages.containsKey(_selectedLanguage)
                  ? _selectedLanguage
                  : 'en-US',
              dropdownColor: const Color(0xFF1E1E1E),
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: _languages.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _selectedLanguage = val);
                  await ref.read(tmdbServiceProvider).saveLanguage(val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Age Certification Country',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _countries.containsKey(_selectedCountry)
                  ? _selectedCountry
                  : 'US',
              dropdownColor: const Color(0xFF1E1E1E),
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: _countries.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _selectedCountry = val);
                  await ref
                      .read(tmdbServiceProvider)
                      .saveCertificationCountry(val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsCard(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final activePlaylistId = ref.watch(activePlaylistIdProvider);

    return StreamBuilder<List<PlaylistsTableData>>(
      stream: db.watchAllPlaylists(),
      builder: (context, snapshot) {
        final playlists = snapshot.data ?? [];
        final PlaylistsTableData? activePlaylist =
            playlists.where((p) => p.id == activePlaylistId).firstOrNull ??
                playlists.firstOrNull;

        final hasPlaylist = activePlaylist != null;
        final playlistName = activePlaylist?.name ?? 'No Playlist Connected';

        final isMobile = MediaQuery.sizeOf(context).width < 768;

        return GlassContainer(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.playlist_play_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                playlistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (hasPlaylist) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.primary, width: 0.8),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasPlaylist
                              ? '${activePlaylist.type.toUpperCase()} • ${activePlaylist.channelCount} items • ${playlists.length} playlist(s) configured'
                              : 'Add your M3U URL, Xtream Codes, or Stalker portal to start watching',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.go('/playlists'),
                    icon: const Icon(Icons.settings_input_component_rounded,
                        size: 16),
                    label: const Text('Manage All Playlists'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/playlists'),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add New Provider'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaybackEngineSelector() {
    final activeEngine = ref.watch(
      playerControllerProvider.select((s) => s.playbackEngine),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Internal Playback Engine',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Switch between libmpv and bundled LibVLC (LGPL v2.1) without installing external apps.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PlaybackEngine.values.map((engine) {
            final selected = activeEngine == engine;
            return ChoiceChip(
              label: Text(engine.label),
              selected: selected,
              onSelected: (_) => ref
                  .read(playerControllerProvider.notifier)
                  .setPlaybackEngine(engine),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.14),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    final isUrl = label.toLowerCase().contains('url') ||
        label.toLowerCase().contains('referer');
    return TvTextField(
      controller: controller,
      labelText: label,
      hintText: hint,
      keyboardType: isUrl ? TextInputType.url : TextInputType.text,
      borderRadius: 10,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
    );
  }

  Widget _buildSwitchRow(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return TvFocusable(
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onPressed: () => onChanged(!value),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          ExcludeFocus(
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return TvFocusable(
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.45), size: 14),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
    );
  }

  Future<void> _importEpg() async {
    final url = _epgUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _epgError = 'Please enter an EPG URL');
      return;
    }

    setState(() {
      _epgLoading = true;
      _epgError = null;
    });

    try {
      await ref.read(epgNotifierProvider.notifier).importEpg(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EPG imported successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _epgUrlController.clear();
      }
    } catch (e) {
      setState(() => _epgError = 'EPG import failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _epgLoading = false);
    }
  }

  Future<void> _clearWatchHistory() async {
    final confirmed = await _showConfirmDialog(
      'Clear Watch History',
      'This will remove all recently watched entries. This cannot be undone.',
    );
    if (confirmed != true) return;

    try {
      final db = ref.read(databaseProvider);
      await db.delete(db.recentlyViewedTable).go();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Watch history cleared'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearEpgCache() async {
    final confirmed = await _showConfirmDialog(
      'Clear EPG Cache',
      'This will delete all stored programme guide data. It can be re-imported from Settings.',
    );
    if (confirmed != true) return;

    try {
      final db = ref.read(databaseProvider);
      await db.delete(db.epgProgramsTable).go();
      await db.delete(db.epgChannelsTable).go();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('EPG cache cleared'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    try {
      final backup = ref.read(backupServiceProvider);
      final result = await backup.saveBackupToDownloads();
      if (result.cancelled) return;

      if (mounted) {
        final destination = result.savedToDownloads
            ? 'Backup saved to Downloads:'
            : 'Backup saved successfully to:';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$destination\n${result.filePath}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final useAnyFilter = !kIsWeb && Platform.isAndroid;
      final res = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Tamba IPTV Backup (.json)',
        type: useAnyFilter ? FileType.any : FileType.custom,
        allowedExtensions: useAnyFilter ? null : ['json'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      final picked = res.files.first;
      final String content;
      if (picked.bytes != null) {
        content = utf8.decode(picked.bytes!);
      } else {
        final bytes = await picked.xFile.readAsBytes();
        content = utf8.decode(bytes);
      }

      final backup = ref.read(backupServiceProvider);
      final result = await backup.importBackupDetailed(content);

      // Refresh in-memory settings immediately after restore.
      await _loadTmdbSettings();
      if (result.forceTvMode != null) {
        DeviceFormFactor.forceTvMode.value = result.forceTvMode!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restored ${result.playlistsCount} playlist(s), '
              '${result.favoritesCount} favorite(s), and settings',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveCustomHeaders() async {
    try {
      final storage = ref.read(secureStorageProvider);
      await storage.savePlaylistCredentials(
          'filimu_custom_user_agent', _userAgentController.text.trim());
      await storage.savePlaylistCredentials(
          'filimu_custom_referer', _refererController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Custom stream headers saved'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showQrCodeDialog() async {
    final ip = await RemoteControlServer.getLocalIp();
    final url = 'http://$ip:8383';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mobile Remote Control',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_2_rounded,
                        size: 120, color: Colors.black),
                    const SizedBox(height: 8),
                    SelectableText(
                      url,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Connect your phone to the same Wi-Fi network and open the address above.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: AppColors.primary),
              label: const Text('Copy URL',
                  style: TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
