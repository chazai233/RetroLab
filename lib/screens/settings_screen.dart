library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/design/prism_theme.dart';
import '../core/hive_boxes.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PrismPalette get p => context.prism;

  late bool _isDarkMode;
  late bool _analogRandomness;
  late DateStampStyle _dateStampStyle;
  late DateStampPosition _dateStampPosition;
  late bool _saveLocationData;

  @override
  void initState() {
    super.initState();
    _isDarkMode = HiveService.isDarkMode;
    _analogRandomness = HiveService.analogRandomnessEnabled;
    _dateStampStyle = DateStampStyle.values.firstWhere(
      (s) => s.name == HiveService.dateStampStyle,
      orElse: () => DateStampStyle.classic90s,
    );
    _dateStampPosition = DateStampPosition.values.firstWhere(
      (p) => p.name == HiveService.dateStampPosition,
      orElse: () => DateStampPosition.bottomRight,
    );
    _saveLocationData = HiveService.saveLocationDataEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _heroCard(),
            const SizedBox(height: 24),
            _sectionTitle('拍摄'),
            _card(
              children: [
                _switchTile(
                  icon: Icons.auto_awesome,
                  title: '每张略有不同',
                  subtitle:
                      '漏光、偏色和颗粒每次都不一样',
                  value: _analogRandomness,
                  onChanged: (v) {
                    setState(() => _analogRandomness = v);
                    HiveService.setAnalogRandomness(v);
                  },
                ),
                _divider(),
                _dropdownTile<DateStampStyle>(
                  icon: Icons.calendar_today,
                  title: '日期样式',
                  value: _dateStampStyle,
                  items: DateStampStyle.values,
                  labelGetter: (s) => s.label,
                  onChanged: (s) {
                    if (s == null) return;
                    setState(() => _dateStampStyle = s);
                    HiveService.setDateStampStyle(s.name);
                  },
                ),
                _divider(),
                _dropdownTile<DateStampPosition>(
                  icon: Icons.place,
                  title: '日期位置',
                  value: _dateStampPosition,
                  items: DateStampPosition.values,
                  labelGetter: (pos) => pos.label,
                  onChanged: (pos) {
                    if (pos == null) return;
                    setState(() => _dateStampPosition = pos);
                    HiveService.setDateStampPosition(pos.name);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle('应用'),
            _card(
              children: [
                _switchTile(
                  icon: Icons.dark_mode,
                  title: '深色',
                  subtitle: _isDarkMode ? '深色' : '浅色',
                  value: _isDarkMode,
                  onChanged: (v) {
                    setState(() => _isDarkMode = v);
                    HiveService.setDarkMode(v);
                  },
                ),
                _divider(),
                _switchTile(
                  icon: Icons.location_off,
                  title: '保存位置',
                  subtitle: '把 GPS 写进照片的 EXIF',
                  value: _saveLocationData,
                  onChanged: (v) {
                    setState(() => _saveLocationData = v);
                    HiveService.setSaveLocationData(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle('关于'),
            _card(
              children: [
                _tile(
                  icon: Icons.help_outline,
                  title: '再看一遍介绍',
                  subtitle: '看看怎么拍',
                  trailing: Icon(Icons.chevron_right, color: p.textMuted),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      ),
                ),
                _divider(),
                _tile(
                  icon: Icons.info_outline,
                  title: RetroStrings.appName,
                  subtitle: '${RetroStrings.tagline}\nv1.0.0',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Building blocks ─────────────────────────────────────────────────────

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '拍摄之前',
            style: GoogleFonts.spaceMono(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '这些选项在按下快门之前就生效。',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: p.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(_analogRandomness ? '随机开' : '随机关', p.amber),
              _chip(_isDarkMode ? '深色' : '浅色', p.cyan),
              _chip(_dateStampStyle.label, p.textMuted),
              _chip(_dateStampPosition.label, p.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: p.cyan,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: p.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(height: 1, thickness: 1, color: p.hairline);

  Widget _iconWell(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
      ),
      child: Icon(icon, size: 19, color: p.amber),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _iconWell(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.45,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
      child: row,
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _tile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _dropdownTile<T>({
    required IconData icon,
    required String title,
    required T value,
    required List<T> items,
    required String Function(T) labelGetter,
    required ValueChanged<T?> onChanged,
  }) {
    return _tile(
      icon: icon,
      title: title,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            dropdownColor: p.panel,
            borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
            isDense: true,
            style: GoogleFonts.spaceMono(fontSize: 11, color: p.textPrimary),
            icon: Icon(Icons.expand_more, size: 18, color: p.textMuted),
            items:
                items
                    .map(
                      (item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(labelGetter(item)),
                      ),
                    )
                    .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
