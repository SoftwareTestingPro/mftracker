import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import 'performance_matrix.dart';

class InvestmentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double currentValue;
  final double invested;
  final double totalReturns;
  final double returnsPct;
  final double xirr;
  final Map<String, double> periodic;
  final Map<String, double>? absolutePeriodic;
  final double? lastNAV;
  final String? lastNAVDate;
  final String? schemeCode;
  final String? plan;
  final IconData? icon;
  final VoidCallback? onTap;

  const InvestmentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentValue,
    required this.invested,
    required this.totalReturns,
    required this.returnsPct,
    required this.xirr,
    required this.periodic,
    this.absolutePeriodic,
    this.lastNAV,
    this.lastNAVDate,
    this.schemeCode,
    this.plan,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final navFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final isPos = totalReturns >= 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: AppTheme.glassDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                if (icon != null) ...[
                  CircleAvatar(
                    backgroundColor: AppTheme.brandPrimary.withValues(alpha: 0.1),
                    child: Icon(icon, color: AppTheme.brandPrimary, size: 18),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (schemeCode != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                schemeCode!,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'monospace'),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${(plan != null && plan!.isNotEmpty) ? "$plan • " : ""}$subtitle',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Value vs Invested
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn('INVESTED', invested, Colors.white, format: currencyFormat),
                _buildMetricColumn('CURRENT VALUE', currentValue, AppTheme.brandPrimary, crossAxis: CrossAxisAlignment.end, format: currencyFormat),
              ],
            ),
            const SizedBox(height: 16),

            // Returns and XIRR
            Row(
              children: [
                _buildMiniStat('Returns', totalReturns, 
                    isPos ? AppTheme.successColor : AppTheme.dangerColor, pct: returnsPct, format: currencyFormat),
                const Spacer(),
                _buildMiniStat('XIRR', xirr, 
                    xirr >= 0 ? AppTheme.successColor : AppTheme.dangerColor, isPercent: true),
              ],
            ),

            // Periodic Matrix
            if (periodic.isNotEmpty) ...[
              const SizedBox(height: 8),
              PerformanceMatrix(
                periodic: periodic,
                absolutePeriodic: absolutePeriodic,
              ),
            ],

            if (lastNAV != null && lastNAV! > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 10, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Last Updated NAV ${navFormat.format(lastNAV)} ${ (lastNAVDate != null && lastNAVDate != 'N/A') ? "as on $lastNAVDate" : ""}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ] else if (schemeCode != null && (lastNAV == null || lastNAV! <= 0)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.dangerColor),
                    SizedBox(width: 8),
                    Text(
                      'NAV DATA UNAVAILABLE - TAP TO RETRY',
                      style: TextStyle(fontSize: 11, color: AppTheme.dangerColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, double value, Color valueColor, {CrossAxisAlignment crossAxis = CrossAxisAlignment.start, required NumberFormat format}) {
    return Column(
      crossAxisAlignment: crossAxis,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCirc,
          builder: (context, val, child) {
            return Text(
              format.format(val),
              style: TextStyle(fontWeight: FontWeight.w800, color: valueColor, fontSize: 22),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, double value, Color valueColor, {double? pct, bool isPercent = false, NumberFormat? format}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCirc,
          builder: (context, val, child) {
            String display = isPercent ? '${val.toStringAsFixed(2)}%' : (format?.format(val) ?? val.toStringAsFixed(0));
            if (pct != null) {
              display = '${val >= 0 ? "+" : ""}${format?.format(val) ?? val.toStringAsFixed(0)} (${pct.toStringAsFixed(2)}%)';
            }
            return Text(
              display,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 18),
            );
          },
        ),
      ],
    );
  }
}
