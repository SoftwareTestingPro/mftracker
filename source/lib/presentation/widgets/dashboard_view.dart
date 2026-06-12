import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../providers/portfolio_provider.dart';
import '../../data/models/fund_investment.dart';
import 'performance_matrix.dart';
import 'investment_card.dart';
import 'add_fund_dialog.dart';
import 'transactions_view.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioSummaryProvider);
    final holdingsAsync = ref.watch(holdingsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portfolio Summary Section
          portfolioAsync.when(
            data: (summary) => _buildSummaryCard(context, summary, currencyFormat),
            loading: () => _buildSummaryCard(context, {}, currencyFormat),
            error: (err, stack) => _buildErrorCard(err.toString()),
          ),
          
          const SizedBox(height: 40),
          
          // Holdings Section
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'My Holdings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddFundDialog(),
                  );
                },
                child: const Text('Add Fund', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          holdingsAsync.when(
            data: (holdings) {
              if (holdings.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('No investments yet. Add a fund to get started.', 
                      style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                );
              }
              final sortedHoldings = [...holdings]..sort((a, b) => (b['xirr'] as double).compareTo(a['xirr'] as double));
              return Column(
                children: sortedHoldings.map((h) => _buildHoldingCard(context, ref, h)).toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => Text('Error: $err'),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> summary, NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn('INVESTED', summary['totalInvestment'] ?? 0, Colors.white),
              _buildMetricColumn('CURRENT VALUE', summary['currentValue'] ?? 0, AppTheme.brandPrimary, alignEnd: true),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Total Returns', 
                  summary['totalReturns'] ?? 0, 
                  summary['totalReturnsPct'] ?? 0,
                  (summary['totalReturns'] ?? 0) >= 0 ? AppTheme.successColor : AppTheme.dangerColor,
                  format: format),
              _buildMiniStat('Overall XIRR', 
                  summary['xirr'] ?? 0, 
                  null,
                  (summary['xirr'] ?? 0) >= 0 ? AppTheme.successColor : AppTheme.dangerColor, 
                  alignEnd: true,
                  isPercent: true),
            ],
          ),
          if (summary['periodic'] != null && (summary['periodic'] as Map).isNotEmpty) ...[
            const SizedBox(height: 16),
            PerformanceMatrix(
              periodic: Map<String, double>.from(summary['periodic']),
              absolutePeriodic: Map<String, double>.from(summary['absolutePeriodic'] ?? {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, dynamic value, Color valueColor, {bool alignEnd = false}) {
    final double numericValue = (value is num) ? value.toDouble() : 0.0;
    final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: numericValue),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCirc,
          builder: (context, val, child) {
            return Text(
              format.format(val),
              style: TextStyle(fontWeight: FontWeight.w800, color: valueColor, fontSize: 28),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, dynamic value, double? pct, Color valueColor, {bool alignEnd = false, bool isPercent = false, NumberFormat? format}) {
    final double numericValue = (value is num) ? value.toDouble() : 0.0;
    
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: numericValue),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCirc,
          builder: (context, val, child) {
            String display = isPercent ? '${val.toStringAsFixed(2)}%' : (format?.format(val) ?? val.toStringAsFixed(0));
            if (pct != null) {
              display += ' (${pct.toStringAsFixed(2)}%)';
            }
            return Text(
              display,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            );
          },
        ),
      ],
    );
  }

  Widget _buildHoldingCard(BuildContext context, WidgetRef ref, Map<String, dynamic> h) {
    final schemeName = h['schemeName'].toString();
    
    // 1. Extract Plan Type (Direct/Regular + Growth/IDCW)
    final lowerName = schemeName.toLowerCase();
    String type = lowerName.contains('direct') ? 'Direct' : 'Regular';
    String option = 'Growth';
    if (lowerName.contains('idcw')) option = 'IDCW';
    else if (lowerName.contains('dividend')) option = 'Dividend';
    
    final planLabel = '$type • $option';

    // 2. Clean up Fund Name (Title)
    // Remove anything starting with common plan/option keywords after a separator
    final cleanupRegex = RegExp(r'\s*[-\s]\s*(?:direct|regular|growth|idcw|dividend|plan|option).*$', caseSensitive: false);
    String fScheme = schemeName.replaceAll(' -', ' - ').replaceAll('- ', ' - ').replaceAll('  ', ' ');
    final cleanName = fScheme.contains(' - ') ? fScheme.split(' - ')[0].trim() : fScheme.replaceFirst(cleanupRegex, '').trim();
    
    final displayTitle = cleanName.toTitleCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: InvestmentCard(
        title: displayTitle,
        plan: planLabel,
        subtitle: '${h['totalUnits'].toStringAsFixed(3)} units • ${h['txCount']} Trans',
        currentValue: (h['currentValue'] ?? 0).toDouble(),
        invested: (h['totalInvested'] ?? 0).toDouble(),
        totalReturns: (h['totalReturns'] ?? 0).toDouble(),
        returnsPct: (h['returnsPct'] ?? 0).toDouble(),
        xirr: (h['xirr'] ?? 0).toDouble(),
        periodic: Map<String, double>.from(h['periodic']),
        absolutePeriodic: Map<String, double>.from(h['absolutePeriodic'] ?? {}),
        lastNAV: (h['currentNAV'] as num?)?.toDouble(),
        lastNAVDate: h['lastNAVDate'] as String?,
        schemeCode: h['schemeCode'],
        onTap: () => _showTransactions(context, ref, h['schemeCode'], h['schemeName']),
      ),
    );
  }

  void _showTransactions(BuildContext context, WidgetRef ref, String schemeCode, String schemeName) {
    // Instead of a modal sheet that hides the bottom nav, we now switch to the History tab
    // and apply a filter. This improves navigation flow and addresses user feedback.
    ref.read(transactionFilterProvider.notifier).state = schemeCode;
    ref.read(transactionFilterNameProvider.notifier).state = schemeName;
    ref.read(navigationIndexProvider.notifier).state = 1; // 1 is the index for 'History' tab
  }



  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('Error: $error', style: const TextStyle(color: AppTheme.dangerColor)),
    );
  }
}
