import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme/tokens.dart';
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
      appBar: AppBar(title: const Text('My orders')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Order>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    'Could not load your orders.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
              );
            }
            final orders = [...(snapshot.data ?? [])]
                .where((o) => o.status != 'cancelled')
                .toList()
              ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
            if (orders.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: AppColors.inkFaint),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'No orders yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Your order history will appear here\nonce you place your first order.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: orders.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _OrderCard(order: orders[i]),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  static bool _isInProgress(String status) =>
      status != 'delivered' && status != 'cancelled';

  @override
  Widget build(BuildContext context) {
    final inProgress = _isInProgress(order.status);
    final itemCount = order.items.fold<int>(0, (s, it) => s + it.quantity);
    final preview = order.items.take(3).map((i) => i.productName).join(', ');
    final more = order.items.length > 3
        ? ' +${order.items.length - 3} more'
        : '';

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brLg,
      elevation: 0,
      child: InkWell(
        borderRadius: AppRadius.brLg,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrackOrderScreen(initialCode: order.publicId),
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.brLg,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.brLg,
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (inProgress) _StatusRibbon(status: order.status),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (!inProgress) _FinalStatusPill(status: order.status),
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
                          const Text(
                            'View details',
                            style: TextStyle(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hh = dt.hour == 0
          ? 12
          : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final mm = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $hh:$mm $ampm';
    } catch (_) {
      return iso;
    }
  }
}

class _StatusRibbon extends StatelessWidget {
  final String status;
  const _StatusRibbon({required this.status});

  ({String label, IconData icon, Color start, Color end}) _spec() {
    switch (status) {
      case 'placed':
        return (
          label: 'Waiting for store confirmation',
          icon: Icons.hourglass_top_rounded,
          start: AppColors.brandBlue,
          end: AppColors.brandBlueDark,
        );
      case 'confirmed':
        return (
          label: 'Order confirmed',
          icon: Icons.check_circle_rounded,
          start: AppColors.brandBlueDark,
          end: AppColors.brandBlue,
        );
      case 'packing':
        return (
          label: 'Packing your order',
          icon: Icons.inventory_2_rounded,
          start: AppColors.brandOrange,
          end: AppColors.brandOrangeDark,
        );
      case 'out_for_delivery':
        return (
          label: 'On the way',
          icon: Icons.delivery_dining_rounded,
          start: AppColors.brandOrangeDark,
          end: AppColors.brandOrange,
        );
      default:
        return (
          label: status,
          icon: Icons.info_outline_rounded,
          start: AppColors.brandBlue,
          end: AppColors.brandBlueDark,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _spec();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [s.start, s.end],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          _PulsingDot(color: Colors.white),
          const SizedBox(width: 8),
          Icon(s.icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Text(
            'IN PROGRESS',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.8,
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
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

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
          width: 16,
          height: 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 8 + t * 8,
                height: 8 + t * 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: (1 - t) * 0.5),
                ),
              ),
              Container(
                width: 8,
                height: 8,
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

class _FinalStatusPill extends StatelessWidget {
  final String status;
  const _FinalStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'delivered' => ('Delivered', AppColors.brandGreen),
      'cancelled' => ('Cancelled', AppColors.danger),
      _ => (status, AppColors.inkFaint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
