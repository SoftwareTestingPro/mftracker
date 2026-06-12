import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../providers/portfolio_provider.dart';
import '../../data/models/fund_investment.dart';
import 'add_fund_dialog.dart';

class TransactionsView extends ConsumerStatefulWidget {
  final String? schemeCode;
  final String? schemeName;

  const TransactionsView({
    super.key,
    this.schemeCode,
    this.schemeName,
  });

  @override
  ConsumerState<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends ConsumerState<TransactionsView> {
  @override
  Widget build(BuildContext context) {
    final investments = ref.watch(investmentsProvider);
    final isLocked = ref.watch(historyLockProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('dd MMM yyyy');

    final filtered = widget.schemeCode != null 
        ? investments.where((inv) => inv.schemeCode == widget.schemeCode).toList()
        : [...investments];

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        color: AppTheme.bgSecondary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_outlined, size: 64, color: Colors.white10),
            const SizedBox(height: 16),
            const Text('No transactions found for this fund.', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            if (widget.schemeCode != null)
              ElevatedButton(
                onPressed: () {
                  ref.read(transactionFilterProvider.notifier).state = null;
                  ref.read(transactionFilterNameProvider.notifier).state = null;
                },
                child: const Text('Clear Filter'),
              ),
          ],
        ),
      );
    }

    final sorted = filtered..sort((a, b) => b.investmentDate.compareTo(a.investmentDate));

    return Container(
      color: AppTheme.bgSecondary,
      child: Column(
        children: [
          if (widget.schemeCode != null) ...[
            const SizedBox(height: 24), // Extra top spacing for better aesthetics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FILTERED BY', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(widget.schemeName ?? 'Selected Fund', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(transactionFilterProvider.notifier).state = null;
                      ref.read(transactionFilterNameProvider.notifier).state = null;
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24), // Added more gap as requested
          _buildLockHeader(isLocked),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final inv = sorted[index];
                final isRedeem = inv.type == 'redeem';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isRedeem ? Colors.redAccent : Colors.blueAccent).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isRedeem ? 'REDEEM' : (inv.purchaseMode == 'sip' ? 'SIP' : 'LUMPSUM'),
                              style: TextStyle(
                                color: isRedeem ? Colors.redAccent : Colors.blueAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                dateFormat.format(inv.investmentDate),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                              ),
                              if (!isLocked) ...[
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
                                  color: AppTheme.bgSecondary,
                                  offset: const Offset(0, 30),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AddFundDialog(existingInvestment: inv),
                                      );
                                    } else if (value == 'delete') {
                                      _showDeleteConfirmation(context, ref, inv);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                                          const SizedBox(width: 8),
                                          Text(inv.sipGroupId != null ? 'Edit All SIP Transactions' : 'Edit', style: const TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                                          const SizedBox(width: 8),
                                          Text(inv.sipGroupId != null ? 'Delete All SIP Transactions' : 'Delete', style: const TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getCleanName(inv.schemeName),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getPlanLabel(inv.schemeName),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currencyFormat.format(inv.investmentAmount.abs()),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isRedeem ? Colors.redAccent : Colors.white,
                                ),
                              ),
                              const Text('Amount', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(inv.nav.toStringAsFixed(4), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Text('NAV', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(inv.units.abs().toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Text('Units', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockHeader(bool isLocked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: (isLocked ? Colors.white.withValues(alpha: 0.05) : AppTheme.brandPrimary.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (isLocked ? Colors.white10 : AppTheme.brandPrimary.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            const SizedBox(width: 40), // Balanced spacing for centered text
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLocked ? 'Transactions Locked' : 'Transactions Unlocked',
                    style: TextStyle(
                      color: isLocked ? Colors.white70 : AppTheme.brandPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLocked 
                      ? 'Tap icon to enable editing' 
                      : 'You can now edit or delete entries',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                ref.read(historyLockProvider.notifier).state = !isLocked;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLocked ? Colors.white.withValues(alpha: 0.05) : AppTheme.brandPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  boxShadow: isLocked ? [] : [
                    BoxShadow(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Icon(
                  isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 24,
                  color: isLocked ? Colors.white38 : AppTheme.brandPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext parentContext, WidgetRef ref, FundInvestment inv) {
    final isSip = inv.sipGroupId != null;
    
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text(isSip ? 'Delete Entire SIP' : 'Delete Transaction', style: const TextStyle(color: Colors.white)),
        content: Text(
          isSip 
            ? 'This is an SIP installment. Deleting it will remove ALL transactions associated with this SIP group for ${inv.schemeName}.' 
            : 'Are you sure you want to delete this transaction for ${inv.schemeName}?', 
          style: const TextStyle(color: AppTheme.textSecondary)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close confirmation
              
              // Show blocking loader on parent context
              showDialog(
                context: parentContext,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                if (isSip) {
                  await ref.read(investmentsProvider.notifier).removeInvestmentsByGroupId(inv.sipGroupId!);
                } else {
                  await ref.read(investmentsProvider.notifier).removeInvestment(inv.id);
                }
                
                if (parentContext.mounted) {
                  Navigator.of(parentContext).pop(); // Close loader
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text(isSip ? 'Entire SIP deleted' : 'Transaction deleted')),
                  );
                }
              } catch (e) {
                if (parentContext.mounted) {
                  Navigator.of(parentContext).pop(); // Close loader
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: Text(isSip ? 'Delete All' : 'Delete', style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _getCleanName(String name) {
    String standardized = name.replaceAll(' -', ' - ').replaceAll('- ', ' - ').replaceAll('  ', ' ');
    if (standardized.contains(' - ')) {
      return standardized.split(' - ')[0].trim().toTitleCase();
    }
    String cleanName = standardized;
    final markers = [' - growth', ' - idcw', ' - dividend', ' - direct', ' - regular', ' growth', ' idcw', ' direct', ' regular'];
    for (var m in markers) {
      final idx = cleanName.toLowerCase().lastIndexOf(m);
      if (idx != -1) cleanName = cleanName.substring(0, idx);
    }
    return cleanName.toTitleCase();
  }

  String _getPlanLabel(String name) {
    final lowerName = name.toLowerCase();
    String type = lowerName.contains('direct') ? 'Direct' : 'Regular';
    String option = 'Growth';
    if (lowerName.contains('idcw')) {
      option = 'IDCW';
    } else if (lowerName.contains('dividend')) {
      option = 'Dividend';
    }
    return '$type • $option';
  }
}
