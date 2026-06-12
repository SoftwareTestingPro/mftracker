import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:math' as Math;
import '../../core/theme.dart';
import '../providers/portfolio_provider.dart';
import 'add_fund_dialog.dart';

class ExploreView extends ConsumerStatefulWidget {
  const ExploreView({super.key});

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  String _selectedCategory = 'Select';
  String _selectedSector = 'Select';
  String _selectedPlan = 'Select';
  String _selectedDuration = 'Select';

  final List<String> _categories = ['Select', 'Equity', 'Debt', 'Hybrid', 'Liquid', 'Index Funds', 'ETFs', 'Tax Saver (ELSS)'];
  final List<String> _sectors = ['Select', 'Small Cap', 'Mid Cap', 'Large Cap', 'Multi Cap', 'Flexi Cap', 'Bluechip', 'Focused', 'Contra', 'Sectoral', 'Thematic'];
  final List<String> _plans = ['Select', 'Direct Growth', 'Direct IDCW', 'Regular Growth', 'Regular IDCW'];
  late final List<String> _durations;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    _durations = [
      'Select', '1 Month', '3 Months', '6 Months', '1 Year', '2 Years', '3 Years', 
      '4 Years', '5 Years', '6 Years', '7 Years', '8 Years', '9 Years', '10 Years'
    ];
    // Add last 10 years
    for (int i = 0; i < 10; i++) {
      _durations.add((currentYear - i).toString());
    }
  }

  int _currentSearchId = 0;

  Future<void> _handleSearch() async {
    if (_selectedCategory == 'Select' || _selectedSector == 'Select' || _selectedPlan == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Category, Section, and Plan to search')),
      );
      return;
    }

    final int searchId = ++_currentSearchId;

    setState(() {
      _isSearching = true;
      _searchResults = []; 
    });

    try {
      final api = ref.read(apiServiceProvider);
      final allFunds = await ref.read(masterFundsProvider.future);
      
      final String sectorPattern = _selectedSector.toLowerCase().replaceAll(' ', '[- ]?');
      final RegExp sectorRegex = RegExp(sectorPattern);

      final List<Map<String, dynamic>> filteredList = allFunds.where((f) {
        final rawName = f['schemeName'].toString().toLowerCase();
        
        // Exclude outdated funds
        if (rawName.contains('ing midcap') || rawName.contains('ing mutual fund')) return false;

        // 1. Sector Check (Flexible Regex)
        if (!sectorRegex.hasMatch(rawName)) return false;

        // 2. Category Check
        if (_selectedCategory == 'Equity' && (rawName.contains('debt') || rawName.contains('liquid') || rawName.contains('gilt'))) return false;

        // 3. Plan & Option Check
        final bool isDirect = rawName.contains('direct');
        if (_selectedPlan.contains('Direct') && !isDirect) return false;
        if (_selectedPlan.contains('Regular') && isDirect) return false;
        if (_selectedPlan.contains('Growth') && !rawName.contains('growth')) return false;
        if (_selectedPlan.contains('IDCW') && !RegExp(r'idcw|dividend|payout').hasMatch(rawName)) return false;

        return true;
      }).toList();

      // Prioritize Reputed AMCs
      const priorityAMCs = ['sbi', 'hdfc', 'icici', 'nippon', 'axis', 'quant', 'jio', 'mirae', 'tata', 'kotak', 'uti', 'bandhan'];
      filteredList.sort((a, b) {
        final nameA = a['schemeName'].toString().toLowerCase();
        final nameB = b['schemeName'].toString().toLowerCase();
        
        int scoreA = priorityAMCs.any((amc) => nameA.contains(amc)) ? 0 : 1;
        int scoreB = priorityAMCs.any((amc) => nameB.contains(amc)) ? 0 : 1;
        
        if (scoreA != scoreB) return scoreA.compareTo(scoreB);
        return nameA.compareTo(nameB);
      });

      if (filteredList.isEmpty) {
        if (mounted && searchId == _currentSearchId) setState(() => _isSearching = false);
        return;
      }

      // Parallel Processing in chunks of 10
      const int chunkSize = 10;
      for (int i = 0; i < filteredList.length; i += chunkSize) {
        if (searchId != _currentSearchId) return;

        final chunk = filteredList.skip(i).take(chunkSize);
        await Future.wait(chunk.map((f) async {
          try {
            final history = await api.getFundHistory(f['schemeCode'].toString());
            if (history != null && history.data.isNotEmpty) {
              final List<dynamic> sortedData = List.from(history.data);
              // Simple sort for performance
              sortedData.sort((a, b) => b.date.split('-').reversed.join().compareTo(a.date.split('-').reversed.join()));

              final lastNavRecord = sortedData.first;
              final currentNav = lastNavRecord.nav;
              final lp = lastNavRecord.date.split('-');
              final latestDate = DateTime(int.parse(lp[2]), int.parse(lp[1]), int.parse(lp[0]));
              
              // Relaxed Activity Check: 14 days
              if (DateTime.now().difference(latestDate).inDays > 14) return;
              
              DateTime? startDate;
              DateTime? endDate;
              bool isCalendarYear = false;

              if (int.tryParse(_selectedDuration) != null) {
                // Specific Year selection (e.g., 2025)
                isCalendarYear = true;
                final year = int.parse(_selectedDuration);
                startDate = DateTime(year, 1, 1);
                
                final currentYear = DateTime.now().year;
                if (year == currentYear) {
                  endDate = latestDate;
                } else {
                  endDate = DateTime(year, 12, 31);
                }
              } else if (_selectedDuration != 'Select') {
                final parts = _selectedDuration.split(' ');
                final val = int.parse(parts[0]);
                int days = 30;
                if (parts[1].startsWith('Month')) days = val * 30;
                else if (parts[1].startsWith('Year')) days = val * 365;
                startDate = latestDate.subtract(Duration(days: days));
                endDate = latestDate;
              }

              if (startDate == null || endDate == null) return;

              // Find closest records for our range
              final pastRecord = api.findClosestRecord(sortedData.cast(), startDate);
              final endRecord = api.findClosestRecord(sortedData.cast(), endDate);

              if (pastRecord != null && endRecord != null && endRecord.nav > 0.01 && pastRecord.nav > 0) {
                final double currentNav = endRecord.nav;
                final double pastNavValue = pastRecord.nav;
                
                final sDate = DateTime.parse(pastRecord.date.split('-').reversed.join('-'));
                final eDate = DateTime.parse(endRecord.date.split('-').reversed.join('-'));
                final int effectiveDays = eDate.difference(sDate).inDays;
                
                double finalReturn;
                if (!isCalendarYear && (_selectedDuration.contains('Year') || _selectedDuration == 'All') && effectiveDays >= 180) {
                  final double years = effectiveDays / 365.25;
                  finalReturn = (Math.pow(currentNav / pastNavValue, 1 / years) - 1) * 100;
                } else {
                  // Use absolute return for Calendar years or short durations
                  finalReturn = ((currentNav - pastNavValue) / pastNavValue) * 100;
                }
                
                if (mounted && searchId == _currentSearchId) {
                  setState(() {
                    final cleanupRegex = RegExp(r'\s*[-\s]\s*(?:direct|regular|growth|idcw|dividend|plan|option).*$', caseSensitive: false);
                    String fScheme = f['schemeName'].toString().replaceAll(' -', ' - ').replaceAll('- ', ' - ').replaceAll('  ', ' ');
                    String cleanName = fScheme.contains(' - ') ? fScheme.split(' - ')[0].trim() : fScheme.replaceFirst(cleanupRegex, '').trim();
                    final displayKey = cleanName.toLowerCase().replaceAll(' ', '');

                    _searchResults = _searchResults.where((item) {
                      String itemScheme = item['schemeName'].toString().replaceAll(' -', ' - ').replaceAll('- ', ' - ').replaceAll('  ', ' ');
                      String existingName = itemScheme.contains(' - ') ? itemScheme.split(' - ')[0].trim() : itemScheme.replaceFirst(cleanupRegex, '').trim();
                      return existingName.toLowerCase().replaceAll(' ', '') != displayKey;
                    }).toList();
                    
                    _searchResults = [..._searchResults, {...f, 'xirr': finalReturn}]
                      ..sort((a, b) => (b['xirr'] as double).compareTo(a['xirr'] as double));
                  });
                }
              }
            }
          } catch (_) {}
        }));

        // Stop loader early if we have enough results
        if (_searchResults.length >= 20 && mounted && searchId == _currentSearchId) setState(() => _isSearching = false);
      }
    } finally {
      if (mounted && searchId == _currentSearchId) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: _buildSectionHeader(context, 'Market Explorer'),
        ),
        const SizedBox(height: 12),
        _buildDiscoveryGrid(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _searchResults.isEmpty 
              ? Center(
                  child: _isSearching 
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(height: 12),
                          Text('Analyzing all funds...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      )
                    : const Text('No active funds match your filters.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14))
                )
              : _buildResultsTable(),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDropdownField('CATEGORY', _selectedCategory, _categories, (v) => setState(() => _selectedCategory = v!))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdownField('SECTION', _selectedSector, _sectors, (v) => setState(() => _selectedSector = v!))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDropdownField('PLAN', _selectedPlan, _plans, (v) => setState(() => _selectedPlan = v!))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdownField('DURATION', _selectedDuration, _durations, (v) => setState(() => _selectedDuration = v!))),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _handleSearch,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.brandPrimary.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: _isSearching 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: AppTheme.bgSecondary,
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13, color: Colors.white)))).toList(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.brandPrimary,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildResultsTable() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgSecondary.withValues(alpha: 0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 25, child: Text('#', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
              const Expanded(child: Text('FUND NAME', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
              SizedBox(width: 70, child: Text(int.tryParse(_selectedDuration) != null ? 'RETURNS' : 'XIRR', textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 28),
            ],
          ),
        ),
        // Rows
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final fund = _searchResults[index];
              return _buildTableRow(fund, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(Map<String, dynamic> fund, int srNo) {
    final double xirr = fund['xirr'] ?? 0.0;
    
    final cleanupRegex = RegExp(r'\s*[-\s]\s*(?:direct|regular|growth|idcw|dividend|plan|option).*$', caseSensitive: false);
    String fScheme = fund['schemeName'].toString().replaceAll(' -', ' - ').replaceAll('- ', ' - ').replaceAll('  ', ' ');
    final cleanName = fScheme.contains(' - ') ? fScheme.split(' - ')[0].trim() : fScheme.replaceFirst(cleanupRegex, '').trim();

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(width: 25, child: Text('$srNo', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(
            child: Text(
              cleanName.toTitleCase(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 70, 
            child: Text(
              '${xirr.toStringAsFixed(2)}%', 
              textAlign: TextAlign.right,
              softWrap: false,
              style: TextStyle(
                color: xirr >= 0 ? AppTheme.successColor : AppTheme.dangerColor, 
                fontSize: 14, 
                fontWeight: FontWeight.bold,
              )
            )
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 24,
            height: 22,
            child: IconButton(
              onPressed: () => _quickAdd(fund),
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.brandPrimary, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _quickAdd(Map<String, dynamic> fund) {
    showDialog(
      context: context,
      builder: (context) => AddFundDialog(initialFund: fund),
    );
  }
}
