import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../providers/portfolio_provider.dart';
import 'performance_matrix.dart';
import 'investment_card.dart';

class CollectionsView extends ConsumerWidget {
  const CollectionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupStatsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return groupsAsync.when(
      data: (groups) {
        if (groups['amc']!.isEmpty && groups['category']!.isEmpty) {
          return const Center(
            child: Text('No investments to group.', style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader(context, 'Market Insights'),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Multi-fund selection for custom groups enabled.')));
                    },
                    icon: const Icon(Icons.add_box_rounded, size: 16),
                    label: const Text('Create Collection', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.brandPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (groups['custom']!.isNotEmpty) ...[
                _buildSectionHeader(context, 'My Collections'),
                const SizedBox(height: 16),
                ...groups['custom']!.map((g) => _buildGroupCard(context, g, currencyFormat, Icons.stars_rounded)),
              ],
              if (groups['amc']!.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'By Fund House'),
                const SizedBox(height: 16),
                ...groups['amc']!.map((g) => _buildGroupCard(context, g, currencyFormat, Icons.account_balance)),
              ],
              if (groups['category']!.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'By Category'),
                const SizedBox(height: 16),
                ...groups['category']!.map((g) => _buildGroupCard(context, g, currencyFormat, Icons.category)),
              ],
              const SizedBox(height: 80),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.brandPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildGroupCard(BuildContext context, Map<String, dynamic> g, NumberFormat format, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: InvestmentCard(
        title: g['name'].toString().toTitleCase(),
        subtitle: '${g['fundCount']} Unique Funds',
        currentValue: (g['currentValue'] ?? 0).toDouble(),
        invested: (g['invested'] ?? 0).toDouble(),
        totalReturns: (g['totalReturns'] ?? 0).toDouble(),
        returnsPct: (g['returnsPct'] ?? 0).toDouble(),
        xirr: (g['xirr'] ?? 0).toDouble(),
        periodic: Map<String, double>.from(g['periodic']),
        absolutePeriodic: Map<String, double>.from(g['absolutePeriodic'] ?? {}),
        icon: icon,
        onTap: () {
          // Future: Navigate to group details
        },
      ),
    );
  }
}
