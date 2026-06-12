import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../providers/portfolio_provider.dart';
import '../../data/models/fund_investment.dart';
import '../../data/models/fund_nav.dart';

class AddFundDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialFund;
  final FundInvestment? existingInvestment;
  const AddFundDialog({super.key, this.initialFund, this.existingInvestment});

  @override
  ConsumerState<AddFundDialog> createState() => _AddFundDialogState();
}

class _AddFundDialogState extends ConsumerState<AddFundDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _unitsController = TextEditingController();
  final _navController = TextEditingController();
  final _dateController = TextEditingController();
  final _searchController = TextEditingController();
  final _houseSearchController = TextEditingController();
  
  final _houseSearchFocus = FocusNode();
  final _fundSearchFocus = FocusNode();
  final _amountFocus = FocusNode();

  DateTime _selectedDate = DateTime.now();
  DateTime? _sipEndDate;
  bool _isOngoingSip = true;
  String _txType = 'purchase'; // 'purchase' or 'redeem'
  String _purchaseMode = 'lumpsum'; // 'lumpsum' or 'sip'
  String _sipFrequency = 'Monthly';
  String _redeemMode = 'amount'; // 'amount' or 'units'

  String? _selectedHouse;
  Map<String, dynamic>? _selectedFundBase;
  List<Map<String, dynamic>> _availablePlans = [];
  Map<String, dynamic>? _selectedPlan;

  bool _addBySchemeCode = false;
  final _schemeCodeController = TextEditingController();
  bool _isValidatingSchemeCode = false;
  String? _schemeCodeError;

  bool _isFetchingNAV = false;
  bool _isSearching = false;
  bool _isSubmitting = false;
  double? _availableUnits;
  double? _availableValue;

  final Map<String, String> _knownMultiWords = {
    "aditya": "Aditya Birla",
    "icici": "ICICI Prudential",
    "kotak": "Kotak Mahindra",
    "canara": "Canara Robeco",
    "mirae": "Mirae Asset",
    "motilal": "Motilal Oswal",
    "nippon": "Nippon India",
    "parag": "Parag Parikh",
    "pgim": "PGIM India",
    "franklin": "Franklin Templeton",
    "whiteoak": "WhiteOak",
    "baroda": "Baroda BNP Paribas",
    "jioblackrock": "JioBlackrock",
    "jio": "JioBlackrock",
    "bandhan": "Bandhan"
  };

  @override
  void initState() {
    super.initState();
    if (widget.existingInvestment != null) {
      final inv = widget.existingInvestment!;
      _selectedDate = inv.investmentDate;
      _txType = inv.type;
      _purchaseMode = inv.purchaseMode ?? 'lumpsum';
      _isOngoingSip = inv.isSipOngoing ?? true;
      _sipEndDate = inv.sipEndDate;
      _selectedHouse = inv.amcName;
      _amountController.text = inv.investmentAmount.abs().toStringAsFixed(2);
      _navController.text = inv.nav.toStringAsFixed(4);
      _unitsController.text = inv.units.abs().toStringAsFixed(3);
      
      if (_txType == 'redeem') {
        // Simple heuristic: if amount was an integer, maybe they used amount mode
        _redeemMode = inv.investmentAmount == inv.investmentAmount.toInt().toDouble() ? 'amount' : 'units';
      }

      _selectedPlan = {
        'schemeCode': inv.schemeCode,
        'schemeName': inv.schemeName,
      };
      _selectedFundBase = _selectedPlan;
      _selectedHouse = inv.amcName;
    }
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    if (widget.initialFund != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prepopulateFromInitialFund();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _houseSearchFocus.requestFocus();
      });
    }
  }

  void _prepopulateFromInitialFund() {
    final fund = widget.initialFund!;
    final name = fund['schemeName'] as String;
    
    // 1. Identify House
    final words = name.split(' ');
    String? foundHouse;
    if (words.isNotEmpty) {
      final first = words[0].toLowerCase().replaceAll(RegExp(r'[^a-zA-Z]'), '');
      foundHouse = _knownMultiWords[first];
      if (foundHouse == null) {
        // Fallback to title case of first word
        foundHouse = first[0].toUpperCase() + first.substring(1).toLowerCase();
      }
    }

    // 2. Identify Base Name
    final baseName = _getBaseMFName(name);

    setState(() {
      _selectedHouse = foundHouse;
      _selectedFundBase = fund;
      _selectedPlan = fund;
      
      // 3. Populate available plans for this base fund
      // Since we don't have allFunds here, we'll use a simplified list containing at least the selected plan
      _availablePlans = [fund];
    });

    _fetchNAV();
    
    // 4. Focus amount field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _unitsController.dispose();
    _navController.dispose();
    _searchController.dispose();
    _houseSearchController.dispose();
    _schemeCodeController.dispose();
    _houseSearchFocus.dispose();
    _fundSearchFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  String _getBaseMFName(String name) {
    String n = name;
    // Standardize separators
    n = n.replaceAll(' -', ' - ').replaceAll('- ', ' - ').replaceAll('  ', ' ');
    
    // If there's a hyphen, the part before it is almost always the base name
    if (n.contains(' - ')) {
      return n.split(' - ')[0].trim();
    }
    
    // Additional aggressive stripping ONLY if there's no hyphen
    final lower = n.toLowerCase();
    final markers = [
      ' growth', ' idcw', ' dividend', ' direct', ' regular', 
      ' plan', ' option', ' payout', ' reinvestment'
    ];
    
    int minIdx = n.length;
    for (var m in markers) {
      final idx = lower.indexOf(m);
      if (idx != -1 && idx < minIdx) minIdx = idx;
    }
    
    return n.substring(0, minIdx).trim();
  }

  String _generateLabel(Map<String, dynamic> plan) {
    final name = plan['schemeName'].toString().toLowerCase();
    String label = name.contains('direct') ? 'Direct' : 'Regular';
    if (name.contains('growth')) {
      label += ' - Growth';
    } else if (name.contains('idcw')) {
      label += ' - IDCW';
    } else if (name.contains('dividend')) {
      label += ' - Dividend';
    }
    return label;
  }

  List<String> _extractHouses(List<Map<String, dynamic>> funds) {
    final Map<String, int> houses = {};
    final blacklist = {'redeemed', 'test', 'zredeemed', 'null', 'the', 'fund', 'mf', 'scheme', 'direct', 'regular'};
    
    for (var f in funds) {
      final name = f['schemeName'] as String? ?? '';
      if (name.isEmpty) continue;
      
      final firstWord = name.trim().split(RegExp(r'\s+'))[0].replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
      if (firstWord.length < 2 || blacklist.any((b) => firstWord.contains(b))) continue;
      
      final dName = _knownMultiWords[firstWord] ?? (firstWord[0].toUpperCase() + firstWord.substring(1).toLowerCase());
      houses[dName] = (houses[dName] ?? 0) + 1;
    }
    
    return houses.entries
        .where((e) => e.value >= 1)
        .map((e) => e.key)
        .toList()
      ..sort();
  }

  Future<void> _fetchNAV() async {
    if (_selectedPlan == null) return;

    setState(() => _isFetchingNAV = true);
    try {
      final api = ref.read(apiServiceProvider);
      final history = await api.getFundHistory(_selectedPlan!['schemeCode'].toString());
      
      if (history != null && history.data.isNotEmpty) {
        final sorted = history.data.toList()..sort((a, b) {
          final pa = a.date.split('-');
          final da = DateTime(int.parse(pa[2]), int.parse(pa[1]), int.parse(pa[0]));
          final pb = b.date.split('-');
          final db = DateTime(int.parse(pb[2]), int.parse(pb[1]), int.parse(pb[0]));
          return da.compareTo(db);
        });

        final parts = sorted.first.date.split('-');
        final inceptionDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));

        if (_selectedDate.isBefore(inceptionDate)) {
          setState(() {
            _selectedDate = inceptionDate;
            _dateController.text = DateFormat('yyyy-MM-dd').format(inceptionDate);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Date adjusted to fund inception date')),
          );
        }

        final nav = await api.getNAVForDate(_selectedPlan!['schemeCode'].toString(), _selectedDate);
        setState(() {
          _navController.text = nav.toStringAsFixed(4);
          _calculateUnits();
        });
      }
    } finally {
      setState(() => _isFetchingNAV = false);
    }
  }

  void _calculateUnits() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final nav = double.tryParse(_navController.text) ?? 0;
    if (nav > 0) {
      if (_txType == 'redeem' && _redeemMode == 'units') {
        _unitsController.text = (-amount).toStringAsFixed(3);
      } else {
        // Apply stamp duty for purchase
        final netAmount = _txType == 'purchase' ? amount * (1 - 0.00005) : amount;
        final units = netAmount / nav;
        _unitsController.text = (_txType == 'redeem' ? -units : units).toStringAsFixed(3);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterFundsAsync = ref.watch(masterFundsProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 800,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: -5,
            )
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                
                masterFundsAsync.when(
                  data: (funds) => _buildFundSelection(funds),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error loading funds: $e', style: const TextStyle(color: Colors.red)),
                ),
                
                if (_selectedPlan != null) ...[
                  const SizedBox(height: 24),
                  if (_txType == 'purchase') _buildPurchaseModeFlow(),
                  if (_txType == 'redeem') ...[
                    _buildDatePicker(),
                    const SizedBox(height: 24),
                    _buildRedeemModeToggle(),
                    const SizedBox(height: 24),
                    _buildAmountField(),
                  ],
                ],
                
                const SizedBox(height: 40),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return _buildTextField(
      _amountController, 
      _getAmountLabel(), 
      Icons.currency_rupee, 
      keyboardType: TextInputType.number, 
      focusNode: _amountFocus,
      onChanged: (v) => _calculateUnits()
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.existingInvestment != null 
                    ? 'Edit Transaction'
                    : (_txType == 'purchase' ? 'Add Fund' : 'Redeem Fund'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildTxTypeToggle(),
      ],
    );
  }

  Widget _buildTxTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSmallToggleButton('Purchase', _txType == 'purchase', () => setState(() { _txType = 'purchase'; _calculateUnits(); })),
          _buildSmallToggleButton('Redeem', _txType == 'redeem', () => setState(() { _txType = 'redeem'; _calculateUnits(); })),
        ],
      ),
    );
  }

  Widget _buildSmallToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brandPrimary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.5)) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFundSelection(List<Map<String, dynamic>> allFunds) {
    if (_txType == 'redeem') {
      final holdingsAsync = ref.watch(holdingsProvider);
      return holdingsAsync.when(
        data: (holdings) => _buildRedeemFundSelection(holdings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Text('Error loading holdings: $e', style: const TextStyle(color: Colors.red)),
      );
    }
    
    if (_addBySchemeCode) {
      return _buildSchemeCodeSelection();
    }
    
    if (_selectedHouse == null) {
      final houses = _extractHouses(allFunds);
      final filteredHouses = houses.where((h) => 
        _houseSearchController.text.isNotEmpty && 
        h.toLowerCase().contains(_houseSearchController.text.toLowerCase())
      ).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Select Fund House', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _addBySchemeCode = true;
                  _schemeCodeError = null;
                }),
                child: const Text('Add by Scheme Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSearchField(_houseSearchController, 'Search House...', (query) => setState(() {}), focusNode: _houseSearchFocus),
          const SizedBox(height: 8),
          if (_houseSearchController.text.isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: filteredHouses.isEmpty
                ? const Center(child: Text('No matching house', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)))
                : ListView.builder(
                    itemCount: filteredHouses.length,
                    itemBuilder: (context, index) {
                      final house = filteredHouses[index];
                      return ListTile(
                        title: Text(house, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        onTap: () {
                          setState(() => _selectedHouse = house);
                          _fundSearchFocus.requestFocus();
                        },
                        dense: true,
                      );
                    },
                  ),
            ),
        ],
      );
    }

    if (_selectedFundBase == null) {
      final houseFunds = allFunds.where((f) => 
        (f['schemeName'] as String).toLowerCase().contains(_selectedHouse!.toLowerCase())
      ).toList();

      final grouped = <String, Map<String, dynamic>>{};
      for (var f in houseFunds) {
        final baseName = _getBaseMFName(f['schemeName']);
        if (!grouped.containsKey(baseName)) {
          grouped[baseName] = f;
        }
      }

      final fundBases = grouped.keys.toList()..sort();
      final filteredBases = fundBases.where((b) =>
        _searchController.text.isNotEmpty &&
        b.toLowerCase().contains(_searchController.text.toLowerCase())
      ).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('House: $_selectedHouse', style: const TextStyle(color: AppTheme.brandPrimary, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: () => setState(() { _selectedHouse = null; _selectedFundBase = null; _selectedPlan = null; }), child: const Text('Change')),
            ],
          ),
          const SizedBox(height: 8),
          _buildSearchField(_searchController, 'Search Fund Name...', (query) => setState(() {}), focusNode: _fundSearchFocus),
          const SizedBox(height: 8),
          if (_searchController.text.isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: filteredBases.isEmpty
                ? const Center(child: Text('No matching funds', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)))
                : ListView.builder(
                    itemCount: filteredBases.length,
                    itemBuilder: (context, index) {
                      final baseName = filteredBases[index];
                      return ListTile(
                        title: Text(baseName, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        onTap: () {
                          setState(() {
                            _selectedFundBase = grouped[baseName];
                            final allMatches = allFunds.where((f) => 
                              (f['schemeName'] as String).toLowerCase().contains(_selectedHouse!.toLowerCase()) &&
                              _getBaseMFName(f['schemeName']) == baseName
                            ).toList();
                            
                            final seen = <String>{};
                            _availablePlans = allMatches.where((f) {
                              final name = f['schemeName'].toString().toLowerCase();
                              String label = name.contains('direct') ? 'Direct' : 'Regular';
                              if (name.contains('growth')) label += ' - Growth';
                              else if (name.contains('idcw')) label += ' - IDCW';
                              else if (name.contains('dividend')) label += ' - Dividend';
                              
                              if (seen.contains(label)) return false;
                              seen.add(label);
                              return true;
                            }).toList();
                            if (_availablePlans.length == 1) {
                              _selectedPlan = _availablePlans[0];
                              _fetchNAV();
                            }
                          });
                        },
                        dense: true,
                      );
                    },
                  ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(_getBaseMFName(_selectedFundBase!['schemeName']), style: const TextStyle(color: AppTheme.brandPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
            TextButton(onPressed: () => setState(() { _selectedFundBase = null; _selectedPlan = null; }), child: const Text('Change')),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Select Plan', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final planGroups = <String, Map<String, dynamic>>{};
            for (var plan in _availablePlans) {
              final label = _generateLabel(plan);
              if (!planGroups.containsKey(label)) {
                planGroups[label] = plan;
              }
            }

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: planGroups.entries.map((e) {
                final label = e.key;
                final plan = e.value;
                final isSelected = _selectedPlan != null && _generateLabel(_selectedPlan!) == label;
                
                return ChoiceChip(
                  label: Text(label, style: TextStyle(fontSize: 14, color: isSelected ? Colors.white : AppTheme.textSecondary)),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() => _selectedPlan = plan);
                    _fetchNAV();
                  },
                  selectedColor: AppTheme.brandPrimary.withValues(alpha: 0.4),
                  backgroundColor: Colors.black.withValues(alpha: 0.2),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSchemeCodeSelection() {
    if (_selectedPlan != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selected Fund (via Scheme Code)', style: TextStyle(color: AppTheme.brandPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_selectedPlan!['schemeName'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedPlan = null;
                    _selectedFundBase = null;
                    _schemeCodeController.clear();
                    _schemeCodeError = null;
                  });
                },
                child: const Text('Change'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Enter Scheme Code', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _addBySchemeCode = false;
                _schemeCodeError = null;
              }),
              child: const Text('Use Name Search'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _schemeCodeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'e.g., 118668',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                  errorText: _schemeCodeError,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isValidatingSchemeCode ? null : _validateAndFetchSchemeCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isValidatingSchemeCode
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _validateAndFetchSchemeCode() async {
    final code = _schemeCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _schemeCodeError = 'Please enter a scheme code');
      return;
    }

    setState(() {
      _isValidatingSchemeCode = true;
      _schemeCodeError = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final history = await api.getFundHistory(code);
      if (history != null && history.data.isNotEmpty) {
        setState(() {
          _selectedPlan = {
            'schemeCode': code,
            'schemeName': history.schemeName,
          };
          _selectedFundBase = _selectedPlan;
          final words = history.schemeName.split(' ');
          if (words.isNotEmpty) {
            final first = words[0].toLowerCase().replaceAll(RegExp(r'[^a-zA-Z]'), '');
            _selectedHouse = _knownMultiWords[first] ?? (first.isNotEmpty ? (first[0].toUpperCase() + first.substring(1).toLowerCase()) : null);
          }
        });
        _fetchNAV();
      } else {
        setState(() => _schemeCodeError = 'Invalid scheme code or no data found');
      }
    } catch (e) {
      setState(() => _schemeCodeError = 'Error fetching scheme details');
    } finally {
      setState(() => _isValidatingSchemeCode = false);
    }
  }

  Widget _buildPurchaseModeFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPurchaseModeToggle(),
        const SizedBox(height: 24),
        if (_purchaseMode == 'lumpsum') ...[
          _buildDatePicker(),
          const SizedBox(height: 24),
          _buildAmountField(),
        ] else ...[
          // SIP Flow
          const Text('SIP Status', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildToggleButton('Ongoing', _isOngoingSip, () => setState(() => _isOngoingSip = true))),
              const SizedBox(width: 8),
              Expanded(child: _buildToggleButton('Stopped', !_isOngoingSip, () => setState(() => _isOngoingSip = false))),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown('Frequency', _sipFrequency, ['Daily', 'Weekly', 'Monthly', 'Quarterly', 'Yearly'], (v) => setState(() => _sipFrequency = v!)),
          const SizedBox(height: 16),
          _buildDatePicker(), // Start Date
          if (!_isOngoingSip) ...[
            const SizedBox(height: 16),
            _buildEndDatePicker(),
          ],
          const SizedBox(height: 24),
          _buildAmountField(),
        ],
      ],
    );
  }

  Widget _buildPurchaseModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: _buildLargeToggleButton('Lumpsum', _purchaseMode == 'lumpsum', () => setState(() => _purchaseMode = 'lumpsum'))),
          Expanded(child: _buildLargeToggleButton('SIP', _purchaseMode == 'sip', () => setState(() => _purchaseMode = 'sip'))),
        ],
      ),
    );
  }

  Widget _buildLargeToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRedeemModeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Redeem By', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildToggleButton('Amount', _redeemMode == 'amount', () => setState(() { _redeemMode = 'amount'; _calculateUnits(); }))),
            const SizedBox(width: 8),
            Expanded(child: _buildToggleButton('Units', _redeemMode == 'units', () => setState(() { _redeemMode = 'units'; _calculateUnits(); }))),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => _selectedDate = date);
          _fetchNAV();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_txType == 'redeem' ? 'REDEMPTION DATE' : (_purchaseMode == 'sip' ? 'SIP START DATE' : 'INVESTMENT DATE'), style: const TextStyle(color: AppTheme.brandPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  DateFormat('dd-MM-yyyy').format(_selectedDate),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const Spacer(),
                const Icon(Icons.calendar_month, size: 20, color: AppTheme.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _sipEndDate ?? DateTime.now(),
          firstDate: _selectedDate,
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => _sipEndDate = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SIP END DATE', style: TextStyle(color: AppTheme.brandPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _sipEndDate != null ? DateFormat('dd-MM-yyyy').format(_sipEndDate!) : 'Select End Date',
                  style: TextStyle(color: _sipEndDate != null ? Colors.white : AppTheme.textSecondary, fontSize: 18),
                ),
                const Spacer(),
                const Icon(Icons.calendar_month, size: 20, color: AppTheme.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(TextEditingController controller, String hint, Function(String) onChanged, {FocusNode? focusNode}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      focusNode: focusNode,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, 
      {TextInputType? keyboardType, bool readOnly = false, FocusNode? focusNode, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      focusNode: focusNode,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        floatingLabelStyle: const TextStyle(color: AppTheme.brandPrimary, fontSize: 14, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.brandPrimary.withValues(alpha: 0.3))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        final val = double.tryParse(v);
        if (val == null || val <= 0) return 'Invalid value';
        
        if (_txType == 'redeem') {
          if (_redeemMode == 'units' && _availableUnits != null) {
            if (val > _availableUnits!) return 'Max ${_availableUnits!.toStringAsFixed(3)} units';
          } else if (_redeemMode == 'amount' && _availableValue != null) {
            if (val > _availableValue!) return 'Max ₹${_availableValue!.toStringAsFixed(0)}';
          }
        }
        return null;
      },
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Colors.white)))).toList(),
          decoration: InputDecoration(
            labelText: label, 
            labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            border: InputBorder.none,
          ),
          dropdownColor: AppTheme.bgSecondary,
        ),
      ),
    );
  }

  String _getAmountLabel() {
    if (_txType == 'redeem') {
      return _redeemMode == 'amount' ? 'Amount to Redeem' : 'Units to Redeem';
    }
    return _purchaseMode == 'sip' ? 'Installment Amount' : 'Investment Amount';
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _selectedPlan == null || _isFetchingNAV || _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: AppTheme.brandPrimary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.brandPrimary.withValues(alpha: 0.3)),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isFetchingNAV || _isSubmitting)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else ...[
                  Icon(widget.existingInvestment != null ? Icons.save : Icons.add, size: 18),
                  const SizedBox(width: 8),
                  Text(widget.existingInvestment != null 
                    ? 'Update Transaction' 
                    : (_txType == 'purchase' ? (_purchaseMode == 'sip' ? 'Generate SIP' : 'Add Fund') : 'Redeem Fund')),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  void _submit() {
    if (_selectedHouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Fund House')));
      _houseSearchFocus.requestFocus();
      return;
    }
    if (_selectedFundBase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Fund Name')));
      _fundSearchFocus.requestFocus();
      return;
    }
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Plan')));
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_purchaseMode == 'sip' && _txType == 'purchase') {
        _handleSIPSubmission();
      } else {
        _handleSingleSubmission();
      }
    }
  }

  Future<void> _handleSingleSubmission() async {
    setState(() => _isSubmitting = true);
    try {
      final amountInput = double.parse(_amountController.text);
      final nav = double.parse(_navController.text);
      
      double finalAmount;
      double finalUnits;

      if (_txType == 'redeem') {
        if (_redeemMode == 'units') {
          finalUnits = -amountInput;
          finalAmount = -(amountInput * nav);
        } else {
          finalAmount = -amountInput;
          finalUnits = -(amountInput / nav);
        }
      } else {
        finalAmount = amountInput;
        finalUnits = double.parse(_unitsController.text);
      }

      final inv = FundInvestment(
        id: widget.existingInvestment?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        schemeCode: _selectedPlan!['schemeCode'].toString(),
        schemeName: _selectedPlan!['schemeName'],
        investmentDate: _selectedDate,
        investmentAmount: finalAmount,
        units: finalUnits,
        nav: nav,
        type: _txType,
        amcName: _selectedHouse,
        purchaseMode: _txType == 'purchase' ? _purchaseMode : null,
      );
      
      if (widget.existingInvestment != null) {
        if (widget.existingInvestment!.sipGroupId != null) {
          await ref.read(investmentsProvider.notifier).removeInvestmentsByGroupId(widget.existingInvestment!.sipGroupId!);
          await ref.read(investmentsProvider.notifier).addInvestment(inv);
        } else {
          await ref.read(investmentsProvider.notifier).updateInvestment(inv);
        }
      } else {
        await ref.read(investmentsProvider.notifier).addInvestment(inv);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Single Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSIPSubmission() async {
    setState(() => _isSubmitting = true);
    try {
      final amount = double.parse(_amountController.text);
      final startDate = _selectedDate;
      final today = DateTime.now();
      
      // If editing, remove the existing record(s)
      if (widget.existingInvestment != null) {
        if (widget.existingInvestment!.sipGroupId != null) {
          await ref.read(investmentsProvider.notifier).removeInvestmentsByGroupId(widget.existingInvestment!.sipGroupId!);
        } else {
          await ref.read(investmentsProvider.notifier).removeInvestment(widget.existingInvestment!.id);
        }
      }

      DateTime currentDate = startDate;
      final List<FundInvestment> newInvestments = [];
      final String sipGroupId = widget.existingInvestment?.sipGroupId ?? 'sip-${DateTime.now().millisecondsSinceEpoch}';
      
      final api = ref.read(apiServiceProvider);
      final history = await api.getFundHistory(_selectedPlan!['schemeCode'].toString());
      
      if (history == null) return;

      final stopDate = _isOngoingSip ? today : (_sipEndDate ?? today);

      while (currentDate.isBefore(stopDate) || currentDate.isAtSameMomentAs(stopDate)) {
        double nav = 0;
        FundNAV? closest;
        for (var navRecord in history.data) {
          final parts = navRecord.date.split('-');
          final recordDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          if (recordDate.isBefore(currentDate) || recordDate.isAtSameMomentAs(currentDate)) {
            if (closest == null) closest = navRecord;
            else {
               final closestParts = closest.date.split('-');
               final closestDate = DateTime(int.parse(closestParts[2]), int.parse(closestParts[1]), int.parse(closestParts[0]));
               if (recordDate.isAfter(closestDate)) closest = navRecord;
            }
          }
        }
        nav = closest?.nav ?? history.data.last.nav;

        final netAmount = amount * (1 - 0.00005);
        final units = netAmount / nav;

        newInvestments.add(FundInvestment(
          id: '${DateTime.now().millisecondsSinceEpoch}-${newInvestments.length}',
          schemeCode: _selectedPlan!['schemeCode'].toString(),
          schemeName: _selectedPlan!['schemeName'],
          investmentDate: currentDate,
          investmentAmount: amount,
          units: units,
          nav: nav,
          type: 'purchase',
          purchaseMode: 'sip',
          sipFrequency: _sipFrequency,
          amcName: _selectedHouse,
          sipGroupId: sipGroupId,
          isSipOngoing: _isOngoingSip,
          sipEndDate: _sipEndDate,
        ));

        if (_sipFrequency == 'Daily') currentDate = currentDate.add(const Duration(days: 1));
        else if (_sipFrequency == 'Weekly') currentDate = currentDate.add(const Duration(days: 7));
        else if (_sipFrequency == 'Monthly') {
          int nextMonth = currentDate.month + 1;
          int nextYear = currentDate.year;
          if (nextMonth > 12) { nextMonth = 1; nextYear++; }
          currentDate = DateTime(nextYear, nextMonth, currentDate.day);
        }
        else if (_sipFrequency == 'Quarterly') {
          int nextMonth = currentDate.month + 3;
          int nextYear = currentDate.year;
          while (nextMonth > 12) { nextMonth -= 12; nextYear++; }
          currentDate = DateTime(nextYear, nextMonth, currentDate.day);
        }
        else if (_sipFrequency == 'Yearly') currentDate = DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
        
        if (newInvestments.length > 500) break;
      }

      await ref.read(investmentsProvider.notifier).addInvestments(newInvestments);
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('SIP Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildRedeemFundSelection(List<Map<String, dynamic>> holdings) {
    if (_selectedPlan == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Holding to Redeem', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: holdings.isEmpty
              ? const Center(child: Text('No active holdings to redeem', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(
                  itemCount: holdings.length,
                  itemBuilder: (context, index) {
                    final h = holdings[index];
                    return ListTile(
                      title: Text(h['schemeName'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      subtitle: Text('${h['totalUnits'].toStringAsFixed(3)} units available', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      onTap: () {
                        setState(() {
                          _selectedPlan = {
                            'schemeCode': h['schemeCode'],
                            'schemeName': h['schemeName'],
                          };
                          _selectedHouse = h['amcName'];
                          _selectedFundBase = _selectedPlan;
                          _availableUnits = h['totalUnits'];
                          _availableValue = h['currentValue'];
                        });
                        _fetchNAV();
                      },
                    );
                  },
                ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(_selectedPlan!['schemeName'], style: const TextStyle(color: AppTheme.brandPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
            TextButton(onPressed: () => setState(() { _selectedPlan = null; _selectedFundBase = null; }), child: const Text('Change')),
          ],
        ),
      ],
    );
  }
}
