import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/socket_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/order_status_badge.dart';

class TrackOrderScreen extends StatefulWidget {
  final String? initialCode;
  const TrackOrderScreen({super.key, this.initialCode});
  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final _codeCtrl = TextEditingController();
  Order? _order;
  RiderLocation? _riderLocation;
  bool _loading = false;
  String _error = '';
  Timer? _pollTimer;
  StreamSubscription? _orderSub, _locationSub;
  bool _deliveredBanner = false;

  static const _timeline = ['placed', 'confirmed', 'packing', 'out_for_delivery', 'delivered'];

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeCtrl.text = widget.initialCode!;
      _fetch(widget.initialCode!);
    }

    _orderSub = SocketService.instance.onOrderUpdated.listen((updated) {
      if (_order?.publicId == updated.publicId) {
        final wasNotDelivered = _order?.status != 'delivered';
        setState(() => _order = updated);
        if (wasNotDelivered && updated.status == 'delivered') {
          setState(() => _deliveredBanner = true);
        }
      }
    });

    _locationSub = SocketService.instance.onRiderLocation.listen((loc) {
      if (_order?.assignedRiderUserId == loc.riderId) {
        setState(() => _riderLocation = loc);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _orderSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _fetch(String code) async {
    setState(() { _loading = true; _error = ''; });
    try {
      final order = await ApiService.trackOrder(code.trim().toUpperCase());
      setState(() {
        _order = order;
        if (order.status == 'delivered') _deliveredBanner = true;
      });
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        try {
          final updated = await ApiService.trackOrder(code.trim().toUpperCase());
          if (mounted) setState(() => _order = updated);
        } catch (_) {}
      });
    } catch (e) {
      setState(() { _error = e.toString(); _order = null; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter tracking code (BM-XXXXXX)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : () => _fetch(_codeCtrl.text),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Track'),
                ),
              ],
            ),

            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(_error, style: const TextStyle(color: AppColors.danger)),
              ),
            ],

            // Delivered banner
            if (_deliveredBanner && _order != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.brandGreen, AppColors.brandGreenDark],
                  ),
                  borderRadius: AppRadius.brMd,
                ),
                child: Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your order has been delivered!',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('Delivered at ${_formatDate(_order!.updatedDate)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => setState(() => _deliveredBanner = false),
                    ),
                  ],
                ),
              ),
            ],

            if (_order != null) ...[
              const SizedBox(height: 16),

              // Status header
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(_order!.publicId,
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                              const SizedBox(width: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  await Clipboard.setData(ClipboardData(
                                      text: _order!.publicId));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Copied ${_order!.publicId}'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.copy,
                                      size: 13, color: AppColors.inkFaint),
                                ),
                              ),
                            ],
                          ),
                          OrderStatusBadge(status: _order!.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_labelStatus(_order!.status),
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3)),
                                const SizedBox(height: 4),
                                Text(
                                  _statusCopy(_order!.status),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: AppRadius.brSm,
                                  border:
                                      Border.all(color: AppColors.borderSoft),
                                ),
                                child: QrImageView(
                                  data: _order!.publicId,
                                  size: 72,
                                  backgroundColor: Colors.white,
                                  version: QrVersions.auto,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: AppColors.ink,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape:
                                        QrDataModuleShape.square,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Scan to track',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.inkFaint,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Timeline
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: _timeline.asMap().entries.map((e) {
                      final idx = e.key;
                      final s = e.value;
                      final currentIdx = _order!.status == 'cancelled'
                          ? -1
                          : _timeline.indexOf(_order!.status);
                      final active = currentIdx >= idx;
                      final isCurrent = currentIdx == idx;
                      final isDelivered =
                          s == 'delivered' && _order!.status == 'delivered';
                      return _TimelineStep(
                        number: idx + 1,
                        label: _labelStatus(s),
                        subtitle: isDelivered
                            ? 'Delivered at ${_formatDate(_order!.updatedDate)}'
                            : isCurrent
                                ? 'In progress now'
                                : active
                                    ? 'Completed'
                                    : 'Pending',
                        active: active,
                        isCurrent: isCurrent,
                        isLast: idx == _timeline.length - 1,
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Live rider location
              if (_order!.status == 'out_for_delivery' && _riderLocation != null) ...[
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            _PulsingDot(),
                            const SizedBox(width: 8),
                            const Text('Rider is on the way',
                                style: TextStyle(color: AppColors.brandBlueDark, fontWeight: FontWeight.w700, fontSize: 14)),
                            const Spacer(),
                            Text(_ageLabel(_riderLocation!.updatedAt),
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                        child: SizedBox(
                          height: 200,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(_riderLocation!.latitude, _riderLocation!.longitude),
                              initialZoom: 15,
                            ),
                            children: [
                              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                              MarkerLayer(markers: [
                                Marker(
                                  point: LatLng(_riderLocation!.latitude, _riderLocation!.longitude),
                                  child: const Icon(Icons.directions_bike, color: AppColors.brandOrange, size: 32),
                                ),
                                if (_order!.deliveryLatitude != null)
                                  Marker(
                                    point: LatLng(_order!.deliveryLatitude!, _order!.deliveryLongitude!),
                                    child: const Icon(Icons.location_pin, color: AppColors.danger, size: 32),
                                  ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Dispatch info
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DISPATCH', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_order!.assignedRider ?? 'Rider assignment pending',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (_order!.assignedRiderPhone != null)
                        InkWell(
                          onTap: () {},
                          child: Text('📞 ${_order!.assignedRiderPhone}', style: const TextStyle(color: AppColors.brandBlue)),
                        ),
                      const SizedBox(height: 4),
                      Text('Payment: ${_order!.paymentMethod == 'cash_on_delivery' ? 'Cash on Delivery' : 'Online'}'),
                      Text('Updated ${_formatDate(_order!.updatedDate)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              // Order items
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ORDER ITEMS', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._order!.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Text('${item.quantity}× ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
                              Expanded(child: Text(item.productName)),
                              Text('₹${(item.lineTotalCents / 100).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                          )),
                      const Divider(),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Delivery', style: TextStyle(color: Colors.grey)),
                        Text(_order!.deliveryFeeCents == 0 ? 'Free' : '₹${(_order!.deliveryFeeCents / 100).toStringAsFixed(0)}'),
                      ]),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('₹${(_order!.totalCents / 100).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.brandGreen)),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  String _statusCopy(String s) => switch (s) {
        'placed' => 'We\'ve received your order and are about to confirm it.',
        'confirmed' =>
          'Your order is confirmed. Our team is picking your items now.',
        'packing' => 'Packing your items with care. Almost ready to dispatch.',
        'out_for_delivery' =>
          'Your rider is on the way — arriving in ~15 minutes.',
        'delivered' => 'Delivered. Enjoy your shopping!',
        'cancelled' =>
          'This order was cancelled. Contact support if this was a mistake.',
        _ => '',
      };

  String _labelStatus(String s) => switch (s) {
        'placed' => 'Order Placed',
        'confirmed' => 'Confirmed',
        'packing' => 'Packing',
        'out_for_delivery' => 'Out for Delivery',
        'delivered' => 'Delivered',
        'cancelled' => 'Cancelled',
        _ => s,
      };

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month-1]} ${dt.year}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  String _ageLabel(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final secs = DateTime.now().difference(dt).inSeconds;
    return secs < 60 ? '${secs}s ago' : '${secs ~/ 60}m ago';
  }
}

class _TimelineStep extends StatelessWidget {
  final int number;
  final String label, subtitle;
  final bool active, isCurrent, isLast;
  const _TimelineStep({
    required this.number,
    required this.label,
    required this.subtitle,
    required this.active,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          isCurrent
              ? _PulseRing(
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.brandGreen,
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      active ? AppColors.brandGreen : AppColors.borderSoft,
                  child: active
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 14)
                      : Text(
                          '$number',
                          style: const TextStyle(
                            color: AppColors.inkFaint,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
          if (!isLast)
            Container(
              width: 2,
              height: 30,
              color: active ? AppColors.brandGreen : AppColors.borderSoft,
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                    fontSize: isCurrent ? 14 : 13,
                    color: active ? AppColors.ink : AppColors.inkFaint,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent
                        ? AppColors.brandGreenDark
                        : active
                            ? AppColors.inkMuted
                            : AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseRing extends StatefulWidget {
  final Widget child;
  const _PulseRing({required this.child});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value;
              return Container(
                width: 28 + 14 * t,
                height: 28 + 14 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandGreen.withValues(alpha: 0.28 * (1 - t)),
                ),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(AppColors.brandGreen, AppColors.brandGreenDark, _ctrl.value),
          ),
        ),
      );
}
