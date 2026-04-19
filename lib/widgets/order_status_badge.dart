import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class OrderStatusBadge extends StatelessWidget {
  final String status;
  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'placed' => ('New', AppColors.brandBlue),
      'confirmed' => ('Confirmed', AppColors.brandBlueDark),
      'packing' => ('Packing', AppColors.brandOrange),
      'out_for_delivery' => ('On the way', AppColors.brandOrangeDark),
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
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
