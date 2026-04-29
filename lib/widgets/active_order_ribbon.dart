import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/active_order_provider.dart';
import '../screens/customer/track_order_screen.dart';
import '../theme/tokens.dart';

/// Floating "track order" ribbon shown above the bottom nav whenever the
/// user has an undelivered order. Pulls live state from
/// [ActiveOrderProvider]; auto-hides the moment the order is marked
/// delivered (or cancelled). Tap → opens [TrackOrderScreen] for the
/// most-recent in-progress order.
class ActiveOrderRibbon extends StatelessWidget {
  const ActiveOrderRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<ActiveOrderProvider>();
    final active = orders.inProgress;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      child: active.isEmpty
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : Padding(
              key: ValueKey(active.first.publicId),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _RibbonCard(order: active.first),
            ),
    );
  }
}

class _RibbonCard extends StatelessWidget {
  final Order order;
  const _RibbonCard({required this.order});

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
          label: 'Order confirmed',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.brandBlueDark,
        );
      case 'packing':
        return (
          label: 'Packing your order',
          icon: Icons.inventory_2_outlined,
          color: AppColors.brandOrange,
        );
      case 'out_for_delivery':
        return (
          label: 'On the way',
          icon: Icons.delivery_dining_rounded,
          color: AppColors.brandOrangeDark,
        );
      default:
        return (
          label: 'Order in progress',
          icon: Icons.shopping_bag_rounded,
          color: AppColors.brandBlue,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _statusSpec();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        // Liquid-glass: blurs whatever is behind the ribbon (bottom of the
        // page content) so it reads as a translucent shelf, not a solid bar.
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      TrackOrderScreen(initialCode: order.publicId),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    spec.color.withValues(alpha: 0.92),
                    spec.color.withValues(alpha: 0.78),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: spec.color.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Pulsing icon avatar — communicates "live, in motion".
                  _PulseDot(color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      spec.icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          spec.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Order #${order.publicId} • Tap to track',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 22,
                  ),
                  // Close button: hides the ribbon for the current order
                  // at its current status. Comes back on next status
                  // update so the user doesn't miss "out for delivery".
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context
                        .read<ActiveOrderProvider>()
                        .dismiss(order.publicId),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

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
                width: 12 * (1 + t),
                height: 12 * (1 + t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: (1 - t) * 0.7),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
