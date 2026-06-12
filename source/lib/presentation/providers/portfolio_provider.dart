import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/fund_investment.dart';
import '../../data/repositories/fund_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/models/fund_group.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/drive_service.dart';
import '../../data/services/financial_calculations.dart';

final apiServiceProvider = Provider((ref) => ApiService());
final driveServiceProvider = Provider((ref) => DriveService(ref.watch(authServiceProvider)));
final fundRepositoryProvider = Provider((ref) => FundRepository(ref.watch(driveServiceProvider)));
final groupRepositoryProvider = Provider((ref) => GroupRepository(ref.watch(driveServiceProvider)));

final masterFundsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getAllFunds();
});

final isSyncingProvider = StateProvider<bool>((ref) => false);
final lastSyncedProvider = StateProvider<DateTime?>((ref) => null);
final refreshCountProvider = StateProvider<int>((ref) => 0);
final historyLockProvider = StateProvider<bool>((ref) => true);
final syncErrorProvider = StateProvider<String?>((ref) => null);

// Navigation & Filtering
final navigationIndexProvider = StateProvider<int>((ref) => 0);
final transactionFilterProvider = StateProvider<String?>((ref) => null);
final transactionFilterNameProvider = StateProvider<String?>((ref) => null);

class InvestmentsNotifier extends Notifier<List<FundInvestment>> {
  @override
  List<FundInvestment> build() {
    // Watch auth state - this ensures the provider is REBUILT when auth state changes
    final authAsync = ref.watch(authStateProvider);
    
    return authAsync.when(
      data: (user) {
        if (user == null) {
          debugPrint('InvestmentsNotifier: No user, returning empty state');
          return [];
        }
        // User logged in, trigger load
        debugPrint('InvestmentsNotifier: User detected (${user.email}), loading data...');
        Future.microtask(() async {
          try {
            // 1. Immediately show the sync icon so user knows we are working
            ref.read(isSyncingProvider.notifier).state = true;
            
            // 2. Initial fast load (cache-first)
            await _loadInvestments();
            
            // 3. Immediate background sync (force refresh from Drive)
            await refreshAll();
          } finally {
            // 4. Guaranteed to stop the spinner
            ref.read(isSyncingProvider.notifier).state = false;
          }
        });
        return []; // Initial state while loading
      },
      loading: () => [],
      error: (e, s) => [],
    );
  }

  Future<void> _loadInvestments({bool forceRefresh = false}) async {
    try {
      debugPrint('InvestmentsNotifier: Loading investments (force: $forceRefresh)...');
      final repo = ref.read(fundRepositoryProvider);
      final investments = await repo.getInvestments(forceRefresh: forceRefresh);
      debugPrint('InvestmentsNotifier: Successfully loaded ${investments.length} investments.');
      state = investments;
      
      // Auto-catchup for SIPs
      _checkAndAddMissingSIPs();
    } catch (e) {
      debugPrint('InvestmentsNotifier: Error loading investments: $e');
    }
  }

  Future<void> _checkAndAddMissingSIPs() async {
    if (state.isEmpty) return;

    final today = DateTime.now();
    // Normalize today to start of day for comparison
    final todayStart = DateTime(today.year, today.month, today.day);
    
    final sipGroups = <String, List<FundInvestment>>{};
    for (final inv in state) {
      if (inv.sipGroupId != null && inv.purchaseMode == 'sip') {
        sipGroups.putIfAbsent(inv.sipGroupId!, () => []).add(inv);
      }
    }

    if (sipGroups.isEmpty) return;

    final List<FundInvestment> catchupInvestments = [];
    bool hasUpdates = false;

    for (final groupId in sipGroups.keys) {
      final members = sipGroups[groupId]!;
      members.sort((a, b) => b.investmentDate.compareTo(a.investmentDate));
      
      final latest = members.first;
      final frequency = latest.sipFrequency;
      if (frequency == null || latest.isSipOngoing == false) continue;

      DateTime nextDate = _calculateNextSIPDate(latest.investmentDate, frequency);
      
      // If next date is today or before, we need to catch up
      if (nextDate.isBefore(todayStart) || nextDate.isAtSameMomentAs(todayStart)) {
        final api = ref.read(apiServiceProvider);
        final history = await api.getFundHistory(latest.schemeCode);
        if (history == null) continue;

        while (nextDate.isBefore(todayStart) || nextDate.isAtSameMomentAs(todayStart)) {
          // Check if this date already exists in the group (safety check)
          final alreadyExists = members.any((m) => 
            m.investmentDate.year == nextDate.year && 
            m.investmentDate.month == nextDate.month && 
            m.investmentDate.day == nextDate.day);
          
          if (!alreadyExists) {
             final nav = _findClosestNAV(history.data, nextDate);
             final netAmount = latest.investmentAmount * (1 - 0.00005);
             final units = netAmount / nav;

             catchupInvestments.add(latest.copyWith(
               id: 'sip-${groupId}-${nextDate.millisecondsSinceEpoch}',
               investmentDate: nextDate,
               units: units,
               nav: nav,
             ));
             hasUpdates = true;
          }
          nextDate = _calculateNextSIPDate(nextDate, frequency);
          if (catchupInvestments.length > 50) break; // Circuit breaker
        }
      }
    }

    if (hasUpdates) {
      debugPrint('InvestmentsNotifier: Adding ${catchupInvestments.length} missing SIP installments.');
      final newState = [...state, ...catchupInvestments];
      state = newState;
      await ref.read(fundRepositoryProvider).saveInvestments(newState);
    }
  }

  DateTime _calculateNextSIPDate(DateTime current, String frequency) {
    if (frequency == 'Daily') return current.add(const Duration(days: 1));
    if (frequency == 'Weekly') return current.add(const Duration(days: 7));
    if (frequency == 'Monthly') {
      int nextMonth = current.month + 1;
      int nextYear = current.year;
      if (nextMonth > 12) { nextMonth = 1; nextYear++; }
      // Use original day or last day of month
      final lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
      final day = current.day > lastDay ? lastDay : current.day;
      return DateTime(nextYear, nextMonth, day);
    }
    if (frequency == 'Quarterly') {
      int nextMonth = current.month + 3;
      int nextYear = current.year;
      while (nextMonth > 12) { nextMonth -= 12; nextYear++; }
      final lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
      final day = current.day > lastDay ? lastDay : current.day;
      return DateTime(nextYear, nextMonth, day);
    }
    if (frequency == 'Yearly') return DateTime(current.year + 1, current.month, current.day);
    return current.add(const Duration(days: 30));
  }

  double _findClosestNAV(List<dynamic> historyData, DateTime target) {
    dynamic closest;
    for (var navRecord in historyData) {
      final parts = navRecord.date.split('-');
      final recordDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      
      if (recordDate.isBefore(target) || recordDate.isAtSameMomentAs(target)) {
        if (closest == null) closest = navRecord;
        else {
          final closestParts = closest.date.split('-');
          final closestDate = DateTime(int.parse(closestParts[2]), int.parse(closestParts[1]), int.parse(closestParts[0]));
          if (recordDate.isAfter(closestDate)) closest = navRecord;
        }
      }
    }
    return closest?.nav ?? historyData.last.nav;
  }

  Future<void> addInvestment(FundInvestment investment) async {
    final newState = [...state, investment];
    state = newState;
    final repo = ref.read(fundRepositoryProvider);
    await repo.saveInvestments(newState);
  }

  Future<void> addInvestments(List<FundInvestment> investments) async {
    final newState = [...state, ...investments];
    state = newState;
    final repo = ref.read(fundRepositoryProvider);
    await repo.saveInvestments(newState);
  }

  Future<void> removeInvestment(String id) async {
    final newState = state.where((i) => i.id != id).toList();
    state = newState;
    final repo = ref.read(fundRepositoryProvider);
    await repo.saveInvestments(newState);
  }

  Future<void> removeInvestmentsByGroupId(String groupId) async {
    final newState = state.where((i) => i.sipGroupId != groupId).toList();
    state = newState;
    final repo = ref.read(fundRepositoryProvider);
    await repo.saveInvestments(newState);
  }

  Future<void> updateInvestment(FundInvestment investment) async {
    final newState = [
      for (final i in state)
        if (i.id == investment.id) investment else i
    ];
    state = newState;
    final repo = ref.read(fundRepositoryProvider);
    await repo.saveInvestments(newState);
  }

  void clearLocal() {
    state = [];
  }

  Future<void> refreshAll() async {
    if (ref.read(isSyncingProvider) && state.isNotEmpty) return;
    
    ref.read(isSyncingProvider.notifier).state = true;
    try {
      // 0. Invalidate API service to clear in-memory cache
      ref.invalidate(apiServiceProvider);

      // 1. Force reload from Google Drive
      await _loadInvestments(forceRefresh: true);
      
      // 2. Refresh groups as well
      final groupsNotifier = ref.read(groupsProvider.notifier);
      await groupsNotifier.loadGroups(forceRefresh: true);

      // 3. Increment refresh count to force HoldingsNotifier to re-process
      ref.read(refreshCountProvider.notifier).state++;
      ref.read(lastSyncedProvider.notifier).state = DateTime.now();
    } catch (e) {
      debugPrint('Sync failed with error: $e');
      if (e is Exception) debugPrint('Sync stack trace: ${StackTrace.current}');
    } finally {
      ref.read(isSyncingProvider.notifier).state = false;
    }
  }
}

final investmentsProvider = NotifierProvider<InvestmentsNotifier, List<FundInvestment>>(InvestmentsNotifier.new);

class GroupsNotifier extends Notifier<List<FundGroup>> {
  @override
  List<FundGroup> build() {
    // Watch auth state
    final authAsync = ref.watch(authStateProvider);
    
    return authAsync.when(
      data: (user) {
        if (user == null) return [];
        Future.microtask(() => loadGroups());
        return [];
      },
      loading: () => [],
      error: (e, s) => [],
    );
  }

  Future<void> loadGroups({bool forceRefresh = false}) async {
    final repo = ref.read(groupRepositoryProvider);
    state = await repo.getGroups(forceRefresh: forceRefresh);
  }

  Future<void> addGroup(FundGroup group) async {
    final newState = [...state, group];
    state = newState;
    final repo = ref.read(groupRepositoryProvider);
    await repo.saveGroups(newState);
  }

  Future<void> removeGroup(String id) async {
    final newState = state.where((g) => g.id != id).toList();
    state = newState;
    final repo = ref.read(groupRepositoryProvider);
    await repo.saveGroups(newState);
  }

  void clearLocal() {
    state = [];
  }
}

final groupsProvider = NotifierProvider<GroupsNotifier, List<FundGroup>>(GroupsNotifier.new);

/// High-performance class for offloading heavy math to background Isolates.
class BackgroundFinancials {
  static Map<String, dynamic> calculateHoldingStats(Map<String, dynamic> params) {
    final List<FundInvestment> sortedInvs = params['investments'];
    final double currentNav = params['currentNav'];
    final dynamic historyData = params['historyData']; // List of FundNAV
    final DateTime earliestDate = params['earliestDate'];
    final double currentValue = params['currentValue'];
    final String currentYearStr = DateTime.now().year.toString();
    final DateTime today = DateTime.now();

    // 1. Moving Average Cost Basis
    double totalUnits = 0;
    double costBasis = 0;
    double realizedGain = 0;
    
    for (var inv in sortedInvs) {
      if (inv.units > 0) {
        totalUnits += inv.units;
        costBasis += inv.investmentAmount;
      } else if (inv.units < 0) {
        final unitsRedeemed = inv.units.abs();
        final avgPriceBefore = totalUnits > 0 ? costBasis / totalUnits : 0;
        final costOfRedeemedUnits = unitsRedeemed * avgPriceBefore;
        final redemptionValue = inv.investmentAmount.abs();
        realizedGain += (redemptionValue - costOfRedeemedUnits);
        totalUnits += inv.units;
        costBasis -= costOfRedeemedUnits;
        if (totalUnits < 0.0001) { totalUnits = 0; costBasis = 0; }
      }
    }

    final unrealizedReturns = (totalUnits * currentNav) - costBasis;
    final returnsPct = costBasis > 0 ? (unrealizedReturns / costBasis) * 100 : 0;
    
    // 2. XIRR
    final List<Map<String, dynamic>> cashFlows = sortedInvs.map((i) => {'date': i.investmentDate, 'amount': -i.investmentAmount}).toList();
    final xirr = FinancialCalculations.calculateXIRR(cashFlows, totalUnits * currentNav);
    
    // 3. Periodic
    Map<String, double> absolutePeriodic = {};
    Map<String, double> periodic = {};
    
    if (historyData != null) {
      final navPeriodic = ApiService().calculatePeriodicReturns(historyData, currentNav, earliestDate: earliestDate);
      navPeriodic.forEach((key, pct) {
        final pastValue = (totalUnits * currentNav) / (1 + (pct / 100));
        absolutePeriodic[key] = (totalUnits * currentNav) - pastValue;
        
        // Annualization logic
        bool shouldAnnualize = false;
        DateTime? startDate;
        if (int.tryParse(key) != null) {
          if (key != currentYearStr) {
            shouldAnnualize = true;
            startDate = DateTime(int.parse(key), 1, 1);
            if (earliestDate.isAfter(startDate)) startDate = earliestDate;
          }
        } else if (key == 'yearly') {
          shouldAnnualize = true;
          startDate = today.subtract(const Duration(days: 365));
        }
        
        if (shouldAnnualize && startDate != null) {
          final years = today.difference(startDate).inDays / 365.25;
          if (years > 0 && pct != 0) {
            periodic[key] = FinancialCalculations.calculateCAGR(totalUnits * currentNav, (totalUnits * currentNav) / (1 + (pct / 100)), startDate);
          } else {
            periodic[key] = pct;
          }
        } else {
          periodic[key] = pct;
        }
      });
    }

    return {
      'totalUnits': totalUnits,
      'totalInvested': costBasis,
      'currentValue': totalUnits * currentNav,
      'totalReturns': unrealizedReturns,
      'returnsPct': returnsPct,
      'realizedGain': realizedGain,
      'xirr': xirr,
      'periodic': periodic,
      'absolutePeriodic': absolutePeriodic,
    };
  }
}

class HoldingsNotifier extends Notifier<AsyncValue<List<Map<String, dynamic>>>> {
  // Track the active loading task to allow cancellation
  List<FundInvestment>? _lastProcessedInvs;
  int _lastRefreshCount = -1;
  bool _isProcessing = false;
  List<Map<String, dynamic>>? _currentResults;
  int _generation = 0;

  @override
  AsyncValue<List<Map<String, dynamic>>> build() {
    final investments = ref.watch(investmentsProvider);
    final refreshCount = ref.watch(refreshCountProvider);
    
    _generation++;
    final currentGen = _generation;
    
    if (investments.isEmpty) {
      _lastProcessedInvs = null;
      _currentResults = [];
      _isProcessing = false;
      _lastRefreshCount = -1;
      return const AsyncValue.data([]);
    }


    // Skip only if investments AND refresh count are identical
    if (listEquals(investments, _lastProcessedInvs) && _lastRefreshCount == refreshCount && _currentResults != null) {
      return AsyncValue.data(_currentResults!);
    }

    _lastProcessedInvs = investments;
    _lastRefreshCount = refreshCount;

    if (!_isProcessing) {
      Future.microtask(() => _loadHoldings(investments, currentGen));
    }

    // Return current results if available, otherwise an empty list to avoid spinners
    if (_currentResults != null) return AsyncValue.data(_currentResults!);
    
    final user = ref.watch(authStateProvider).value;
    if (user != null) {
      _loadFromCache(user.id);
    }

    return const AsyncValue.data([]);
  }

  Future<void> _loadFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cached = prefs.getString('cached_holdings_$userId');
      if (cached != null) {
        final List<dynamic> decoded = jsonDecode(cached);
        final results = decoded.map((h) {
          final map = Map<String, dynamic>.from(h);
          if (map['earliestDate'] != null) map['earliestDate'] = DateTime.parse(map['earliestDate']);
          if (map['periodic'] != null) map['periodic'] = Map<String, double>.from(map['periodic']);
          if (map['absolutePeriodic'] != null) map['absolutePeriodic'] = Map<String, double>.from(map['absolutePeriodic']);
          return map;
        }).toList();
        
        // Populate state with cached data if we have nothing better yet
        if (_currentResults == null || _currentResults!.isEmpty) {
          _currentResults = results;
          state = AsyncValue.data(results);
        }
      }
    } catch (e) {
      print('Cache load error: $e');
    }
  }

  Future<void> _loadHoldings(List<FundInvestment> allInvestments, int myGen) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final api = ref.read(apiServiceProvider);
    final grouped = <String, List<FundInvestment>>{};
    for (var inv in allInvestments) {
      grouped.putIfAbsent(inv.schemeCode, () => []).add(inv);
    }
    
    // Always start with existing results to avoid 'flicker' or 'zeroing out' while updating.
    final Map<String, Map<String, dynamic>> workingMap = {};
    if (_currentResults != null) {
      for (var h in _currentResults!) {
        if (grouped.containsKey(h['schemeCode'])) {
          workingMap[h['schemeCode']] = h;
        }
      }
    }

    int completedCount = 0;
    final entries = grouped.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      if (myGen != _generation) {
        debugPrint('HoldingsNotifier: New generation detected. Aborting task $myGen.');
        _isProcessing = false;
        return;
      }

      final entry = entries[i];
      final code = entry.key;
      final invs = entry.value;

      try {
        final sortedInvs = List<FundInvestment>.from(invs)..sort((a, b) => a.investmentDate.compareTo(b.investmentDate));
        final earliestDate = sortedInvs.first.investmentDate;
        
        final history = await api.getFundHistory(code);
        final currentNav = history?.data.isNotEmpty == true ? history!.data.first.nav : 0.0;

        // Offload heavy math to background Isolate
        final stats = await compute(BackgroundFinancials.calculateHoldingStats, {
          'investments': sortedInvs,
          'currentNav': currentNav,
          'historyData': history?.data,
          'earliestDate': earliestDate,
          'currentValue': 0.0,
        });

        if (stats['totalUnits'] > 0.0001 || stats['totalInvested'].abs() > 0.01 || stats['realizedGain'].abs() > 0.01) {
          final holding = {
            ...stats,
            'currentNAV': currentNav,
            'schemeCode': code,
            'schemeName': invs.first.schemeName,
            'amcName': invs.first.amcName,
            'txCount': invs.length,
            'lastNAVDate': history?.data.isNotEmpty == true ? history!.data.first.date : 'N/A',
            'earliestDate': earliestDate,
          };
          
          workingMap[code] = holding;
        }
      } catch (e) {
        debugPrint('Error loading holding $code: $e');
      } finally {
        completedCount++;
        
        if (myGen != _generation) {
           _isProcessing = false;
           return;
        }

        // REMOVED: Partial state updates (completedCount % 2) to prevent flickering
      }
    }

    // Ensure final state is set and persisted
    final finalResults = workingMap.values.toList();
    _currentResults = finalResults;
    
    if (myGen == _generation) {
      state = AsyncValue.data(finalResults);
      
      try {
        final user = ref.read(authStateProvider).value;
        if (user != null) {
          _saveToCache(finalResults, user.id);
        }
      } catch (e) {
        debugPrint('Sync: Could not save to cache during rebuild: $e');
      }
    }
    
    _isProcessing = false;
  }

  Future<void> _saveToCache(List<Map<String, dynamic>> results, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> serializable = results.map((h) {
        final map = Map<String, dynamic>.from(h);
        if (map['earliestDate'] is DateTime) {
          map['earliestDate'] = (map['earliestDate'] as DateTime).toIso8601String();
        }
        return map;
      }).toList();
      await prefs.setString('cached_holdings_$userId', jsonEncode(serializable));
    } catch (e) {
      print('Error saving holdings to cache: $e');
    }
  }
}

final holdingsProvider = NotifierProvider<HoldingsNotifier, AsyncValue<List<Map<String, dynamic>>>>(HoldingsNotifier.new);

final portfolioSummaryProvider = Provider<AsyncValue<Map<String, dynamic>>>((ref) {
  final holdingsAsync = ref.watch(holdingsProvider);
  final investments = ref.watch(investmentsProvider);
  
  return holdingsAsync.when(
    data: (holdings) {
      if (holdings.isEmpty) {
        return const AsyncValue.data({
          'totalInvestment': 0.0,
          'currentValue': 0.0,
          'totalReturns': 0.0,
          'totalReturnsPct': 0.0,
          'xirr': 0.0,
          'periodic': <String, double>{},
          'absolutePeriodic': <String, double>{},
        });
      }

    double totalCostBasis = 0;
    double totalCurrentValue = 0;
    double totalRealizedGain = 0;
    Map<String, double> totalDiff = {};
    Map<String, double> totalPastValue = {};

    for (var h in holdings) {
      totalCostBasis += (h['totalInvested'] ?? 0);
      totalCurrentValue += (h['currentValue'] ?? 0);
      totalRealizedGain += (h['realizedGain'] ?? 0);
      
      final absolutePeriodic = h['absolutePeriodic'] as Map<String, double>;
      for (var entry in absolutePeriodic.entries) {
        final val = entry.value;
        totalDiff[entry.key] = (totalDiff[entry.key] ?? 0) + val;
        final hPastValue = (h['currentValue'] as double) - val;
        totalPastValue[entry.key] = (totalPastValue[entry.key] ?? 0) + hPastValue;
      }
    }

    final Map<String, double> periodicReturns = {};
    final today = DateTime.now();
    final currentYearStr = today.year.toString();
    for (var key in totalDiff.keys) {
      if (totalPastValue[key] != null && totalPastValue[key]! > 0) {
        final absVal = (totalDiff[key]! / totalPastValue[key]!) * 100;
        
        bool shouldAnnualize = false;
        DateTime? startDate;

        if (int.tryParse(key) != null) {
          if (key != currentYearStr) {
            shouldAnnualize = true;
            startDate = DateTime(int.parse(key), 1, 1);
            // Find earliest date among holdings for this year
            DateTime? minStart;
            for (var h in holdings) {
              if (h['periodic'].containsKey(key)) {
                final hStart = h['earliestDate'] as DateTime;
                if (minStart == null || hStart.isBefore(minStart)) minStart = hStart;
              }
            }
            if (minStart != null && minStart.isAfter(startDate)) startDate = minStart;
          }
        } else if (key == 'yearly') {
          shouldAnnualize = true;
          startDate = today.subtract(const Duration(days: 365));
        }

        if (shouldAnnualize && startDate != null) {
          final years = today.difference(startDate).inDays / 365.25;
          if (years > 0 && absVal != 0) {
            periodicReturns[key] = FinancialCalculations.calculateCAGR(totalCurrentValue, totalCurrentValue / (1 + (absVal / 100)), startDate);
          } else {
            periodicReturns[key] = absVal;
          }
        } else {
          periodicReturns[key] = absVal;
        }
      }
    }

    // Re-calculating global XIRR based ONLY on loaded holdings
    final List<Map<String, dynamic>> cashFlows = [];
    final loadedSchemeCodes = holdings.map((h) => h['schemeCode'] as String).toSet();
    
    for (var inv in investments) {
      if (loadedSchemeCodes.contains(inv.schemeCode)) {
        cashFlows.add({'date': inv.investmentDate, 'amount': -inv.investmentAmount});
      }
    }
    
    final globalXirr = FinancialCalculations.calculateXIRR(cashFlows, totalCurrentValue);

    final totalReturns = totalCurrentValue - totalCostBasis;
    final totalReturnsPct = totalCostBasis > 0 ? (totalReturns / totalCostBasis) * 100 : 0;

    return AsyncValue.data({
      'totalInvestment': totalCostBasis,
      'currentValue': totalCurrentValue,
      'totalReturns': totalReturns,
      'totalReturnsPct': totalReturnsPct,
      'unrealizedReturns': totalCurrentValue - totalCostBasis,
      'realizedReturns': totalRealizedGain,
      'xirr': globalXirr,
      'periodic': periodicReturns,
      'absolutePeriodic': totalDiff,
    });
  },
  loading: () => const AsyncValue.loading(),
  error: (err, stack) => AsyncValue.error(err, stack),
  );
});

final groupStatsProvider = Provider<AsyncValue<Map<String, List<Map<String, dynamic>>>>>((ref) {
  final holdingsAsync = ref.watch(holdingsProvider);
  
  return holdingsAsync.whenData((holdings) {
      final amcGroups = <String, List<Map<String, dynamic>>>{};
      final catGroups = <String, List<Map<String, dynamic>>>{};

      final categories = [
        {'name': 'Small Cap', 'keywords': ['small cap', 'smallcap', 'micro']},
        {'name': 'Mid Cap', 'keywords': ['midcap', 'mid cap']},
        {'name': 'Large Cap', 'keywords': ['large cap', 'bluechip', 'top 100', 'focused']},
        {'name': 'Flexi Cap', 'keywords': ['flexi cap', 'flexicap']},
        {'name': 'Index & ETF', 'keywords': ['index', 'nifty', 'sensex', 'etf', 'passive']},
        {'name': 'Tax Saver (ELSS)', 'keywords': ['elss', 'tax saver', 'tax saving']},
        {'name': 'Debt & Bonds', 'keywords': ['debt', 'bond', 'gilt', 'corporate']},
        {'name': 'Hybrid & Balanced', 'keywords': ['hybrid', 'balanced', 'arbitrage', 'multi asset']},
      ];

      for (var h in holdings) {
        // AMC Grouping
        final amc = h['amcName'] ?? 'Others';
        amcGroups.putIfAbsent(amc, () => []).add(h);

        // Category Grouping
        final name = h['schemeName'].toString().toLowerCase();
        bool matched = false;
        for (var cat in categories) {
          if ((cat['keywords'] as List<String>).any((k) => name.contains(k))) {
            final catName = cat['name'] as String;
            catGroups.putIfAbsent(catName, () => []).add(h);
            matched = true;
            break;
          }
        }
        if (!matched) {
          catGroups.putIfAbsent('Others', () => []).add(h);
        }
      }

      List<Map<String, dynamic>> calculateStats(Map<String, List<Map<String, dynamic>>> groups) {
        return groups.entries.map((entry) {
          final name = entry.key;
          final groupHoldings = entry.value;
          
          double invested = 0;
          double value = 0;
          double realized = 0;
          
          // Dynamically collect all period keys from group holdings
          final Set<String> allPeriodKeys = {};
          for (var h in groupHoldings) {
            allPeriodKeys.addAll((h['periodic'] as Map<String, double>).keys);
          }
          final Map<String, double> totalDiff = { for (var k in allPeriodKeys) k: 0.0 };
          final Map<String, double> totalPastValue = { for (var k in allPeriodKeys) k: 0.0 };

          for (var h in groupHoldings) {
            invested += h['totalInvested'];
            value += h['currentValue'];
            realized += (h['realizedGain'] ?? 0);
            
            final absolutePeriodic = h['absolutePeriodic'] as Map<String, double>;
            for (var pEntry in absolutePeriodic.entries) {
              final val = pEntry.value;
              totalDiff[pEntry.key] = (totalDiff[pEntry.key] ?? 0) + val;
              final hPastValue = (h['currentValue'] as double) - val;
              totalPastValue[pEntry.key] = (totalPastValue[pEntry.key] ?? 0) + hPastValue;
            }
          }

          final returns = value - invested;
          final returnsPct = invested > 0 ? (returns / invested) * 100 : 0;
          
          final Map<String, double> periodicReturns = {};
          final today = DateTime.now();
          final currentYearStr = today.year.toString();
          for (var key in totalDiff.keys) {
            if (totalPastValue[key]! > 0) {
              final absVal = (totalDiff[key]! / totalPastValue[key]!) * 100;

              bool shouldAnnualize = false;
              DateTime? startDate;

              if (int.tryParse(key) != null) {
                if (key != currentYearStr) {
                  shouldAnnualize = true;
                  startDate = DateTime(int.parse(key), 1, 1);
                  // Find earliest date among group holdings for this year
                  DateTime? minStart;
                  for (var h in groupHoldings) {
                    if (h['periodic'].containsKey(key)) {
                      final hStart = h['earliestDate'] as DateTime;
                      if (minStart == null || hStart.isBefore(minStart)) minStart = hStart;
                    }
                  }
                  if (minStart != null && minStart.isAfter(startDate)) startDate = minStart;
                }
              } else if (key == 'yearly') {
                shouldAnnualize = true;
                startDate = today.subtract(const Duration(days: 365));
              }

              if (shouldAnnualize && startDate != null) {
                final years = today.difference(startDate).inDays / 365.25;
                if (years > 0 && absVal != 0) {
                  periodicReturns[key] = FinancialCalculations.calculateCAGR(value, value / (1 + (absVal / 100)), startDate);
                } else {
                  periodicReturns[key] = absVal;
                }
              } else {
                periodicReturns[key] = absVal;
              }
            }
          }

          // Group-level XIRR
          final allInvs = ref.read(investmentsProvider);
          final List<Map<String, dynamic>> groupCashFlows = [];
          for (var h in groupHoldings) {
            final fundInvs = allInvs.where((i) => i.schemeCode == h['schemeCode']);
            for (var inv in fundInvs) {
              groupCashFlows.add({'date': inv.investmentDate, 'amount': -inv.investmentAmount});
            }
          }
          final groupXirr = FinancialCalculations.calculateXIRR(groupCashFlows, value);

          return {
            'name': name,
            'invested': invested,
            'currentValue': value,
            'totalReturns': returns,
            'returnsPct': returnsPct,
            'xirr': groupXirr,
            'periodic': periodicReturns,
            'absolutePeriodic': totalDiff,
            'fundCount': groupHoldings.length,
          };
        }).toList()..sort((a, b) => (b['xirr'] as double).compareTo(a['xirr'] as double));
      }

      // Custom Groups
      final customGroups = <String, List<Map<String, dynamic>>>{};
      final userGroups = ref.watch(groupsProvider);
      
      for (var ug in userGroups) {
        final groupHoldings = holdings.where((h) {
          // Check if any investment in this holding is in the custom group
          final investments = ref.read(investmentsProvider).where((i) => i.schemeCode == h['schemeCode']);
          return investments.any((i) => ug.fundIds.contains(i.id));
        }).toList();
        
        if (groupHoldings.isNotEmpty) {
          customGroups[ug.name] = groupHoldings;
        }
      }

      return {
        'amc': calculateStats(amcGroups),
        'category': calculateStats(catGroups),
        'custom': calculateStats(customGroups),
      };
    });
});
