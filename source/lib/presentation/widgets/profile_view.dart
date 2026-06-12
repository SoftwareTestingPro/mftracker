import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/auth_service.dart';
import '../providers/portfolio_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../screens/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/security_provider.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_outlined, size: 64, color: AppTheme.textSecondary),
                const SizedBox(height: 16),
                const Text('Session Expired', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Please log in again to sync your data.', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => auth.signIn(),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandPrimary),
                  child: const Text('Sign In with Google'),
                ),
              ],
            ),
          );
        }

        final displayName = user.displayName ?? 'User Name';
        final email = user.email;
        final photoUrl = user.photoUrl;

        // Split name into first and last
        final names = displayName.split(' ');
        final firstName = names.isNotEmpty ? names[0] : '';
        final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.3), width: 2),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderAvatar(displayName, size: 40),
                        )
                      : Image.network(
                          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=random',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderAvatar(displayName, size: 40),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 12),
              if (firstName.isNotEmpty) 
                Text(
                  '$firstName ${lastName.isNotEmpty ? lastName : ""}', 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                ),
              Text(email, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 48),
              
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),
              const Text(
                'DIAGNOSTICS',
                style: TextStyle(color: AppTheme.brandPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final investments = ref.watch(investmentsProvider);
                  final syncError = ref.watch(syncErrorProvider);
                  final lastSynced = ref.watch(lastSyncedProvider);
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSecondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDiagRow('Local Investments', '${investments.length}'),
                        _buildDiagRow('Sync Error', syncError ?? 'None', color: syncError != null ? Colors.redAccent : Colors.greenAccent),
                        _buildDiagRow('Last Sync', lastSynced != null ? lastSynced.toIso8601String().substring(0, 16) : 'Never'),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'ACTIONS',
                style: TextStyle(color: AppTheme.brandPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final isSyncing = ref.watch(isSyncingProvider);
                  return _buildProfileAction(
                    icon: Icons.sync,
                    title: 'Refresh Data',
                    subtitle: 'Manually sync with Google Drive',
                    trailing: isSyncing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandPrimary))
                      : null,
                    onTap: isSyncing ? () {} : () => ref.read(investmentsProvider.notifier).refreshAll(),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'SECURITY',
                style: TextStyle(color: AppTheme.brandPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final security = ref.watch(securityProvider);
                  return _buildProfileAction(
                    icon: Icons.lock_outline_rounded,
                    title: 'App Lock',
                    subtitle: 'Secure with Fingerprint or PIN',
                    trailing: Switch(
                      value: security.isEnabled,
                      onChanged: (val) => ref.read(securityProvider.notifier).toggleSecurity(val),
                      activeColor: AppTheme.brandPrimary,
                    ),
                    onTap: () => ref.read(securityProvider.notifier).toggleSecurity(!security.isEnabled),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'LEGAL & SUPPORT',
                style: TextStyle(color: AppTheme.brandPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              _buildProfileAction(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read our data protection terms',
                onTap: () => _showDocumentModal(context, 'Privacy Policy', 'assets/PRIVACY_POLICY.md'),
              ),
              const SizedBox(height: 12),
              _buildProfileAction(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Review user agreement & rules',
                onTap: () => _showDocumentModal(context, 'Terms of Service', 'assets/TERMS_OF_SERVICE.md'),
              ),
              const SizedBox(height: 12),
              _buildProfileAction(
                icon: Icons.bug_report_outlined,
                title: 'Report a Bug',
                subtitle: 'Connect with developer for feedback',
                onTap: () {
                  final body = 'User: ${user.email}\n'
                              'Name: ${user.displayName}\n'
                              'Environment: ${Theme.of(context).platform}\n'
                              '-----------------------------------\n'
                              'Please describe the bug below:\n\n';
                  _launchURL('mailto:automation.sushil@gmail.com?subject=MFTracker%20Bug%20Report&body=${Uri.encodeComponent(body)}');
                },
              ),
              const SizedBox(height: 12),
              _buildProfileAction(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out from MFTracker',
                onTap: () async {
                  await auth.signOut();
                  // Reset navigation and clear stale state for next user
                  ref.read(navigationIndexProvider.notifier).state = 0;
                  ref.invalidate(investmentsProvider);
                  ref.invalidate(groupsProvider);
                  ref.invalidate(holdingsProvider);
                  
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildProfileAction(
                icon: Icons.delete_forever_outlined,
                title: 'Delete Profile',
                subtitle: 'Revoke access and clear data',
                onTap: () => _showDeleteConfirmation(context, auth, ref),
                isDestructive: true,
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  Future<void> _showDocumentModal(BuildContext context, String title, String assetPath) async {
    final content = await rootBundle.loadString(assetPath);
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 32),
              Expanded(
                child: Markdown(
                  data: content,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                    h1: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    h2: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    h3: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    strong: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AuthService auth, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: const Text('Delete Profile?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will disconnect your Google account and stop MFTracker from accessing your Drive. Local cache will also be cleared.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                // 1. Wipe data from Google Drive
                final drive = ref.read(driveServiceProvider);
                await drive.deleteAllFiles();
                
                // 2. Reset all in-memory state
                ref.invalidate(investmentsProvider);
                ref.invalidate(groupsProvider);
                ref.invalidate(holdingsProvider);
                ref.invalidate(securityProvider);
                ref.invalidate(lastSyncedProvider);
                ref.invalidate(syncErrorProvider);
                ref.invalidate(navigationIndexProvider);
                ref.invalidate(transactionFilterProvider);

                // 3. Disconnect Google account and wipe SharedPreferences
                await auth.deleteAccount();

                if (context.mounted) {
                  // Close loading and confirmation dialogs
                  Navigator.of(context).pop(); // Close loader
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loader
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error during wipe: $e'), backgroundColor: AppTheme.dangerColor),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProfileAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withValues(alpha: 0.05) : AppTheme.bgSecondary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDestructive ? Colors.red.withValues(alpha: 0.1) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDestructive ? Colors.redAccent : AppTheme.brandPrimary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive ? Colors.redAccent : Colors.white)),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            if (trailing != null) trailing
            else const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar(String name, {double size = 14}) {
    final initials = name.isNotEmpty ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase() : '?';
    return Container(
      color: AppTheme.bgSecondary,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size),
      ),
    );
  }
}
