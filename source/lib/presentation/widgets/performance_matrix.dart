import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';

class PerformanceMatrix extends StatelessWidget {
  final Map<String, double> periodic;
  final Map<String, double>? absolutePeriodic;
  final EdgeInsetsGeometry? margin;

  const PerformanceMatrix({
    super.key,
    required this.periodic,
    this.absolutePeriodic,
    this.margin,
  });

  /// Maps internal period keys to user-facing labels.
  static const Map<String, String> _periodLabels = {
    'daily': '1D',
    'weekly': '1W',
    'fortnightly': '15D',
    'monthly': '1M',
    'quarterly': '3M',
    'halfYearly': '6M',
    'yearly': '1Y',
  };

  /// Defines the display order for standard (non-year) periods.
  static const List<String> _periodOrder = [
    'daily', 'weekly', 'fortnightly', 'monthly', 'quarterly', 'halfYearly', 'yearly',
  ];

  /// Returns an ordered list of period keys present in the data.
  List<String> _getOrderedKeys() {
    final List<String> ordered = [];
    for (var key in _periodOrder) {
      if (periodic.containsKey(key)) ordered.add(key);
    }
    final yearKeys = periodic.keys
        .where((k) => int.tryParse(k) != null)
        .toList()
      ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));
    ordered.addAll(yearKeys);
    return ordered;
  }

  String _labelFor(String key) => _periodLabels[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final keys = _getOrderedKeys();
    if (keys.isEmpty) return const SizedBox.shrink();

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      margin: margin,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: keys.map((key) {
            final val = periodic[key] ?? 0;
            final absVal = absolutePeriodic?[key];
            final isP = val >= 0;
            final color = isP ? AppTheme.successColor : AppTheme.dangerColor;

            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Text(
                    _labelFor(key),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isP ? '+' : ''}${val.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (absVal != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      '${absVal >= 0 ? '+' : '-'}${currencyFormat.format(absVal.abs())}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
