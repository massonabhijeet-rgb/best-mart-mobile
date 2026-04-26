import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme/tokens.dart';
import '../../widgets/liquid_glass.dart';
import 'track_order_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getMyOrders();
  }

  Future<void> _refresh() async {
    final next = ApiService.getMyOrders();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'My orders',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: LiquidGlassBackground(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Order>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandBlue,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        kToolbarHeight + AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.lg),
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          color: AppColors.inkFaint, size: 48),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Could not load your orders.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                  );
                }
                final all = [...(snapshot.data ?? [])]
                    .where((o) => o.status != 'cancelled')
                    .toList()
                  ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
                if (all.isEmpty) return const _EmptyOrders();

                final inProgress =
                    all.where((o) => _OrderCard._isInProgress(o.status)).toList();
                final past = all
                    .where((o) => !_OrderCard._isInProgress(o.status))
                    .toList();

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      MediaQuery.of(context).padding.top +
                          kToolbarHeight +
                          AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xl),
                  children: [
                    if (inProgress.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'In progress',
                        count: inProgress.length,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final o in inProgress) ...[
                        _OrderCard(order: o),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                    if (past.isNotEmpty) ...[
                      if (inProgress.isNotEmpty)
                        const SizedBox(height: AppSpacing.md),
                      _SectionHeader(
                        label: 'Past orders',
                        count: past.length,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final o in past) ...[
                        _OrderCard(order: o),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          MediaQuery.of(context).padding.top +
              kToolbarHeight +
              AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xl),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              borderRadius: AppRadius.brLg,
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 56, color: AppColors.brandBlue),
                SizedBox(height: AppSpacing.md),
                Text(
                  'No orders yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Your order history will appear here\nonce you place your first order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  static bool _isInProgress(String status) =>
      status != 'delivered' && status != 'cancelled';

  ({String label, IconData icon, Color color}) _statusSpec() {
    switch (order.status) {
      case 'placed':
        return (
          label: 'Awaiting confirmation',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.brandBlue,
        );
      case 'confirmed':
        return (
          label: 'Confirmed',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.brandBlueDark,
        );
      case 'packing':
        return (
          label: 'Packing',
          icon: Icons.inventory_2_outlined,
          color: AppColors.brandOrange,
        );
      case 'out_for_delivery':
        return (
          label: 'On the way',
          icon: Icons.delivery_dining_rounded,
          color: AppColors.brandOrangeDark,
        );
      case 'delivered':
        return (
          label: 'Delivered',
          icon: Icons.check_circle_rounded,
          color: AppColors.brandGreen,
        );
      case 'cancelled':
        return (
          label: 'Cancelled',
          icon: Icons.cancel_outlined,
          color: AppColors.danger,
        );
      default:
        return (
          label: order.status,
          icon: Icons.info_outline_rounded,
          color: AppColors.inkFaint,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = _isInProgress(order.status);
    final spec = _statusSpec();
    final itemCount = order.items.fold<int>(0, (s, it) => s + it.quantity);
    final preview = order.items.take(3).map((i) => i.productName).join(', ');
    final more =
        order.items.length > 3 ? ' +${order.items.length - 3} more' : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.brLg,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrackOrderScreen(initialCode: order.publicId),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            // Liquid-glass surface — translucent over the storefront's
            // drifting blob backdrop. Soft shadow + thin border give
            // the card depth without the heavy 1.5-pixel surround.
            color: AppColors.surface.withValues(alpha: 0.88),
            borderRadius: AppRadius.brLg,
            border:
                Border.all(color: AppColors.borderSoft.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status colour stripe — replaces the heavy gradient
              // ribbon. A single 4px coloured rail down the left edge
              // is enough to convey state at a glance.
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: spec.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${order.publicId}',
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: spec.label,
                            icon: spec.icon,
                            color: spec.color,
                            pulsing: inProgress,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(order.createdDate),
                        style: const TextStyle(
                          color: AppColors.inkFaint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'} · $preview$more',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Text(
                            '₹${(order.totalCents / 100).toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            inProgress ? 'Track order' : 'View details',
                            style: const TextStyle(
                              color: AppColors.brandBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.brandBlue,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Smarter date formatting:
  ///   - Today, 3:20 PM
  ///   - Yesterday, 1:15 PM
  ///   - 12 Apr · 4:30 PM         (this year)
  ///   - 12 Apr 2024 · 4:30 PM    (older)
  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final orderDay = DateTime(dt.year, dt.month, dt.day);
      final daysAgo = today.difference(orderDay).inDays;
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final hh = dt.hour == 0
          ? 12
          : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final mm = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      final time = '$hh:$mm $ampm';
      if (daysAgo == 0) return 'Today, $time';
      if (daysAgo == 1) return 'Yesterday, $time';
      if (dt.year == now.year) {
        return '${dt.day} ${months[dt.month - 1]} · $time';
      }
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $time';
    } catch (_) {
      return iso;
    }
  }
}

/// Compact status pill that goes top-right on each card. Pulses with a
/// dot when the order is still in progress; static for terminal states.
class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool pulsing;
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.pulsing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulsing) ...[
            _PulsingDot(color: color),
            const SizedBox(width: 6),
          ] else ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return SizedBox(
          width: 12,
          height: 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 6 + t * 6,
                height: 6 + t * 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: (1 - t) * 0.45),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
