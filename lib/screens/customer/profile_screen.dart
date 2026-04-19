import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../theme/tokens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to place orders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, saved addresses, and '
          'notification settings. Past orders are kept in the store records '
          'for compliance but are no longer linked to you. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().deleteAccount();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account',
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.sm),
                      _Row(label: 'Email', value: user.email),
                      if ((user.fullName ?? '').isNotEmpty)
                        _Row(label: 'Name', value: user.fullName!),
                      if ((user.phone ?? '').isNotEmpty)
                        _Row(label: 'Phone', value: user.phone!),
                      _Row(label: 'Store', value: user.companyName),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Card(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout_rounded),
                        title: const Text('Log out'),
                        onTap: _busy ? null : _confirmLogout,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.delete_forever_rounded,
                          color: AppColors.danger,
                        ),
                        title: const Text(
                          'Delete account',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        subtitle: const Text(
                          'Permanently remove your profile and saved data',
                        ),
                        onTap: _busy ? null : _confirmDelete,
                      ),
                    ],
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: child,
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.inkFaint, fontSize: 13)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
}
