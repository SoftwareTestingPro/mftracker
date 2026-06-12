import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../providers/portfolio_provider.dart';
import '../widgets/dashboard_view.dart';
import '../widgets/collections_view.dart';
import '../widgets/explore_view.dart';
import '../widgets/transactions_view.dart';
import '../widgets/profile_view.dart';
import '../widgets/add_fund_dialog.dart';
import '../widgets/security_wrapper.dart';
import '../../data/services/auth_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetIdleTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock on app closed/background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _lockHistory();
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 2), () {
      _lockHistory();
    });
  }

  void _lockHistory() {
    ref.read(historyLockProvider.notifier).state = true;
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0: return const DashboardView();
      case 1: {
        final filterCode = ref.watch(transactionFilterProvider);
        final filterName = ref.watch(transactionFilterNameProvider);
        return TransactionsView(schemeCode: filterCode, schemeName: filterName);
      }
      case 2: return const CollectionsView();
      case 3: return const ExploreView();
      case 4: return const ProfileView();
      default: return const DashboardView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationIndexProvider);
    return SecurityWrapper(
      child: Listener(
        onPointerDown: (_) => _resetIdleTimer(),
        onPointerMove: (_) => _resetIdleTimer(),
        child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-1.0, -1.0),
              radius: 1.5,
              colors: [
                Color(0x263B82F6),
                Colors.transparent,
              ],
              stops: [0.0, 1.0],
            ),
          ),
          child: SafeArea(
            child: NestedScrollView(
              key: ValueKey(selectedIndex),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
              ],
              body: KeyedSubtree(
                key: ValueKey(selectedIndex),
                child: _getPage(selectedIndex),
              ),
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddFundDialog(context),
          backgroundColor: AppTheme.brandPrimary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    ),
  );
}

  void _showAddFundDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddFundDialog(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Title and Subtitle
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.chartLine, color: AppTheme.brandPrimary, size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Mutual Fund Tracker',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Track your mutual funds anonymously',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),

          // Right side: Sync and Profile
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final isSyncing = ref.watch(isSyncingProvider);
                  if (!isSyncing) return const SizedBox.shrink();
                  
                  return const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandPrimary),
                    ),
                  );
                },
              ),
              Consumer(
                builder: (context, ref, child) {
                  final userAsync = ref.watch(authStateProvider);
                  return userAsync.when(
                    data: (user) {
                      final displayName = user?.displayName ?? 'Guest User';
                      final photoUrl = user?.photoUrl;
                      
                      return InkWell(
                        onTap: () {
                          _lockHistory();
                          ref.read(navigationIndexProvider.notifier).state = 4;
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: ClipOval(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderAvatar(displayName),
                                  )
                                : Image.network(
                                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=random&color=fff',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderAvatar(displayName),
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const CircleAvatar(radius: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const CircleAvatar(radius: 18, child: Icon(Icons.person)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar(String name) {
    final initials = name.isNotEmpty ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase() : '?';
    return Container(
      color: AppTheme.bgSecondary,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildBottomNav() {
    final selectedIndex = ref.watch(navigationIndexProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary.withValues(alpha: 0.8),
        border: const Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          if (index != selectedIndex) {
            _lockHistory(); // Lock whenever we change tabs
            // Clear transaction filter when manually switching tabs
            ref.read(transactionFilterProvider.notifier).state = null;
            ref.read(transactionFilterNameProvider.notifier).state = null;
          }
          ref.read(navigationIndexProvider.notifier).state = index;
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppTheme.brandPrimary,
        unselectedItemColor: AppTheme.textSecondary,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.chartPie, size: 20, color: selectedIndex == 0 ? AppTheme.brandPrimary : AppTheme.textSecondary), 
            label: 'My Funds'
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.clockRotateLeft, size: 20, color: selectedIndex == 1 ? Colors.orangeAccent : AppTheme.textSecondary), 
            label: 'History'
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.layerGroup, size: 20, color: selectedIndex == 2 ? Colors.purpleAccent : AppTheme.textSecondary), 
            label: 'Collections'
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.compass, size: 20, color: selectedIndex == 3 ? Colors.tealAccent : AppTheme.textSecondary), 
            label: 'Explore'
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.user, size: 20, color: selectedIndex == 4 ? Colors.pinkAccent : AppTheme.textSecondary), 
            label: 'Profile'
          ),
        ],
      ),
    );
  }
}
