import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/tokens.dart';

class PublicCouponCarousel extends StatefulWidget {
  final List<Coupon> coupons;
  // When provided, tapping a coupon calls [onApply] with the code instead of
  // copying to the clipboard. Used on checkout to apply the coupon inline.
  final Future<bool> Function(String code)? onApply;
  const PublicCouponCarousel({
    super.key,
    required this.coupons,
    this.onApply,
  });

  @override
  State<PublicCouponCarousel> createState() => _PublicCouponCarouselState();
}

class _PublicCouponCarouselState extends State<PublicCouponCarousel> {
  String? _copiedCode;

  static const List<_Palette> _palettes = [
    _Palette(Color(0xFF0D9488), Color(0xFF0F766E), Colors.white),
    _Palette(Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFF1F1300)),
    _Palette(Color(0xFF6366F1), Color(0xFF4F46E5), Colors.white),
    _Palette(Color(0xFFEC4899), Color(0xFFDB2777), Colors.white),
    _Palette(Color(0xFF0EA5E9), Color(0xFF0369A1), Colors.white),
  ];

  Future<void> _handleTap(String code) async {
    HapticFeedback.selectionClick();
    final onApply = widget.onApply;
    if (onApply != null) {
      final ok = await onApply(code);
      if (!mounted) return;
      if (ok) {
        setState(() => _copiedCode = code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coupon "$code" applied'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copiedCode = code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coupon "$code" copied — apply it at checkout'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_copiedCode == code) setState(() => _copiedCode = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.coupons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        0,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎟  Limited-time offers',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkFaint,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Save more with coupon codes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.onApply != null
                      ? 'Tap a coupon to apply it'
                      : 'Tap a coupon to copy the code',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkFaint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: AppSpacing.md),
              itemCount: widget.coupons.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) {
                final c = widget.coupons[i];
                final palette = _palettes[i % _palettes.length];
                return _CouponCard(
                  coupon: c,
                  palette: palette,
                  isCopied: _copiedCode == c.code,
                  isApplyMode: widget.onApply != null,
                  onCopy: () => _handleTap(c.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Palette {
  final Color from;
  final Color to;
  final Color ink;
  const _Palette(this.from, this.to, this.ink);
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  final _Palette palette;
  final bool isCopied;
  final bool isApplyMode;
  final VoidCallback onCopy;

  const _CouponCard({
    required this.coupon,
    required this.palette,
    required this.isCopied,
    required this.isApplyMode,
    required this.onCopy,
  });

  String get _discountBig {
    if (coupon.discountType == 'percent') {
      return '${coupon.discountValue.toInt()}%';
    }
    return '₹${(coupon.discountValue / 100).toInt()}';
  }

  String get _minLabel {
    final min = coupon.minSubtotalCents ?? 0;
    if (min > 0) return 'Min ₹${(min / 100).toInt()}';
    return 'No minimum';
  }

  String? get _capLabel {
    if (coupon.discountType == 'percent' && coupon.maxDiscountCents != null) {
      return 'Up to ₹${(coupon.maxDiscountCents! / 100).toInt()}';
    }
    return null;
  }

  String get _expiryLabel {
    final until = coupon.validUntil;
    if (until == null || until.isEmpty) return 'No expiry';
    try {
      final d = DateTime.parse(until).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return 'Until ${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return 'Limited time';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCopy,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.from, palette.to],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.brMd,
          boxShadow: AppShadow.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _discountBig,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: palette.ink,
                        height: 1,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'OFF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: palette.ink.withValues(alpha: 0.85),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        coupon.description ?? 'Save big on your next order.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          _chip(_minLabel),
                          if (_capLabel != null) _chip(_capLabel!),
                          _chip(_expiryLabel),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: palette.ink.withValues(alpha: 0.15),
                borderRadius: AppRadius.brSm,
                border: Border.all(
                  color: palette.ink.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CODE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: palette.ink.withValues(alpha: 0.75),
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        coupon.code,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCopied
                            ? Icons.check_rounded
                            : (isApplyMode
                                ? Icons.bolt_rounded
                                : Icons.copy_rounded),
                        size: 14,
                        color: palette.ink,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCopied
                            ? (isApplyMode ? 'Applied' : 'Copied')
                            : (isApplyMode ? 'Apply' : 'Copy'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) => Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: palette.ink.withValues(alpha: 0.85),
        ),
      );
}
