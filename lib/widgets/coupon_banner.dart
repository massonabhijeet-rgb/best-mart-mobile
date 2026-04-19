import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/tokens.dart';

class CouponBanner extends StatefulWidget {
  final List<Coupon> coupons;
  const CouponBanner({super.key, required this.coupons});

  @override
  State<CouponBanner> createState() => _CouponBannerState();
}

class _CouponBannerState extends State<CouponBanner> {
  late final PageController _ctrl = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  void _startAuto() {
    _timer?.cancel();
    if (widget.coupons.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_page + 1) % widget.coupons.length;
      _ctrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.coupons.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 96,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.coupons.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _CouponCard(coupon: widget.coupons[i]),
            ),
          ),
        ),
        if (widget.coupons.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.coupons.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.brandBlue : AppColors.borderSoft,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  const _CouponCard({required this.coupon});

  String get _headline {
    if (coupon.discountType == 'percent') {
      return '${coupon.discountValue.toStringAsFixed(0)}% OFF';
    }
    return '₹${(coupon.discountValue / 100).toStringAsFixed(0)} OFF';
  }

  String? get _urgency {
    final raw = coupon.validUntil;
    if (raw == null || raw.isEmpty) return null;
    final until = DateTime.tryParse(raw);
    if (until == null) return null;
    final now = DateTime.now();
    final diff = until.difference(now);
    if (diff.isNegative) return null;
    if (diff.inHours < 24) return 'Ends today';
    final days = diff.inDays;
    if (days <= 7) return 'Ends in ${days}d';
    return null;
  }

  String? get _minSpend {
    final m = coupon.minSubtotalCents;
    if (m == null || m <= 0) return null;
    return 'Min ₹${(m / 100).toStringAsFixed(0)}';
  }

  Future<void> _apply(BuildContext context) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: coupon.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code ${coupon.code} copied — paste at checkout'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urgency = _urgency;
    final minSpend = _minSpend;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.brMd,
        onTap: () => _apply(context),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandBlue, AppColors.brandBlueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.brMd,
            boxShadow: AppShadow.soft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Text(
                    _headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              coupon.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (urgency != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandOrange,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule,
                                      color: Colors.white, size: 10),
                                  const SizedBox(width: 3),
                                  Text(
                                    urgency,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coupon.description ?? minSpend ?? 'Tap APPLY to copy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (minSpend != null && coupon.description != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          minSpend,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: const Text(
                    'APPLY',
                    style: TextStyle(
                      color: AppColors.brandBlueDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
