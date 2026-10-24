library;

import 'package:flutter/material.dart';
import '../core/design/prism_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../widgets/grain_overlay.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // Stateful only so the private builders below can read `context` for the
  // palette; there is no mutable state here.
  PrismPalette get p => context.prism;

  @override
  Widget build(BuildContext context) {
    final totalShots = HiveService.totalShots;
    final totalRolls = HiveService.totalRolls;
    final favoriteStock = FilmStocks.getById(HiveService.favoriteStockId);
    final usageMap = Map<String, int>.from(
      HiveService.statsBox.get('stock_usage', defaultValue: {}) as Map,
    );

    // Hoisted out of the per-stock map below, where it was recomputed on every
    // iteration — O(n²) inside build().
    final maxCount =
        usageMap.values.isEmpty
            ? 1
            : usageMap.values.reduce((a, b) => a > b ? a : b);
    // Only stocks actually shot. Rendering all 19, most at 0%, was pure noise.
    final usedStocks =
        FilmStocks.all.where((s) => (usageMap[s.id] ?? 0) > 0).toList()
          ..sort((a, b) => (usageMap[b.id] ?? 0).compareTo(usageMap[a.id] ?? 0));

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('统计')),
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.03)),
          SingleChildScrollView(
            padding: const EdgeInsets.all(RetroDimens.paddingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroCard(totalShots, totalRolls, favoriteStock),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.camera_alt_outlined,
                        value: '$totalShots',
                        label: '总张数',
                        color: p.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        icon: Icons.camera_roll_outlined,
                        value: '$totalRolls',
                        label: '用过的卷',
                        color: p.dateYellow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _statCard(
                  icon: favoriteStock.icon,
                  value: favoriteStock.name,
                  label: '最常用的卷',
                  color: p.stockInk(favoriteStock.badgeColor),
                  wide: true,
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: '胶卷用量',
                  subtitle: '每卷拍了多少。',
                  child: Column(
                    children: [
                      ...usedStocks.map((stock) {
                        final count = usageMap[stock.id] ?? 0;
                        final fraction = maxCount > 0 ? count / maxCount : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    stock.icon,
                                    size: 16,
                                    color: p.stockInk(stock.badgeColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    stock.shortName,
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$count disparos',
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 11,
                                      color: p.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  backgroundColor: p.surfaceHigh,
                                  valueColor: AlwaysStoppedAnimation(
                                    p.stockInk(stock.badgeColor),
                                  ),
                                  minHeight: 7,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: '小结',
                  subtitle: '你最近怎么拍的。',
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: p.dateYellow,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getFunFact(totalShots),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: p.textMuted,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(int totalShots, int totalRolls, FilmStock favoriteStock) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '相册一览',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: p.amber,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            totalShots == 0
                ? '还没有冲洗过照片。'
                : '已经冲洗 $totalShots 张。',
            style: GoogleFonts.spaceMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '拍过 $totalRolls 卷，最常用的是 ${favoriteStock.shortName}。',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: p.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('共 $totalShots 张', p.amber),
              _summaryChip('$totalRolls 卷', p.dateYellow),
              _summaryChip(
                'TOP ${favoriteStock.shortName}',
                p.stockInk(favoriteStock.badgeColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.amber,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: p.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(RetroDimens.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool wide = false,
  }) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: wide ? 16 : 24,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
            textAlign: wide ? TextAlign.left : TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: p.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _getFunFact(int shots) {
    if (shots == 0) return '相册是空的。先去拍一张。';
    if (shots < 10) return '刚开始拍，继续就好。';
    if (shots < 50) {
      return '已经留下 $shots 张。'
          '';
    }
    if (shots < 100) {
      return '已经拍了 $shots 张。'
          '要不要换一卷试试。';
    }
    return '已经冲洗 $shots 张。'
        '';
  }
}
