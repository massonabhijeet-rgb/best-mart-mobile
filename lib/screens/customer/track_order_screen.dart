import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/google_maps_service.dart';
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

  // Route display: we prefer the server-cached polyline attached to the order
  // (which the backend refreshes every ~500m of rider drift, costing us ~1
  // Directions call per order). If for some reason the order doesn't have a
  // cached route yet, we fall back to calling Directions directly — at most
  // once per order — just so the UI isn't empty.
  final Completer<GoogleMapController> _mapCtrl = Completer();
  List<LatLng> _routePoints = [];
  String? _directionsFallbackOrderId;
  int? _routeEtaSeconds;
  String? _decodedPolylineCache;

  // Custom map markers — built once on screen mount so the rider shows
  // up as a recognisable scooter pin (and the destination as a home
  // pin) instead of the generic Google Maps coloured droplets. Falls
  // back to the default coloured pin until the bitmaps are ready.
  BitmapDescriptor? _riderMarkerIcon;
  BitmapDescriptor? _destinationMarkerIcon;

  static const _timeline = ['placed', 'confirmed', 'packing', 'out_for_delivery', 'delivered'];

  @override
  void initState() {
    super.initState();
    _buildCustomMarkers();
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
        _maybeFetchRoute();
      }
    });

    _locationSub = SocketService.instance.onRiderLocation.listen((loc) {
      if (_order?.assignedRiderUserId == loc.riderId) {
        setState(() => _riderLocation = loc);
        _maybeFetchRoute();
      }
    });
  }

  /// Builds the rider + destination map pins. The rider uses a
  /// custom PNG asset (assets/icon/rider_icon.png) downsized to a
  /// pin-friendly size; the destination is Canvas-drawn so we
  /// don't need a second asset for it. Built once on mount and
  /// cached so location updates don't re-create the bitmap.
  Future<void> _buildCustomMarkers() async {
    final rider = await _bitmapFromAsset(
      'assets/icon/rider_icon.png',
      targetSize: 86, // logical pixels — kept small so the pin
                     //   doesn't dominate the 220-tall map area.
    );
    final destination = await _circleIconMarker(
      icon: Icons.home_rounded,
      ringColor: AppColors.danger,
      iconColor: AppColors.danger,
      size: 84,
    );
    if (!mounted) return;
    setState(() {
      _riderMarkerIcon = rider;
      _destinationMarkerIcon = destination;
    });
  }

  /// Loads a PNG asset, resizes it to `targetSize`, and returns it
  /// as a BitmapDescriptor. Uses `instantiateImageCodec` with target
  /// dimensions so a high-res source PNG (e.g. 1024×1024) doesn't
  /// render as a giant pin on the map.
  Future<BitmapDescriptor> _bitmapFromAsset(
    String assetPath, {
    required int targetSize,
  }) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: targetSize,
      targetHeight: targetSize,
    );
    final frame = await codec.getNextFrame();
    final bytes =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// Renders a circular marker bitmap: outer coloured ring + white
  /// inner disc + the supplied Material icon glyph centred on top.
  /// Returned as a BitmapDescriptor ready to drop into a Marker.
  Future<BitmapDescriptor> _circleIconMarker({
    required IconData icon,
    required Color ringColor,
    required Color iconColor,
    double size = 110,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final centre = Offset(size / 2, size / 2);

    // Soft outer shadow so the pin lifts off the map.
    canvas.drawCircle(
      centre.translate(0, 3),
      size / 2 - 4,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Coloured outer ring.
    canvas.drawCircle(
      centre,
      size / 2 - 4,
      Paint()..color = ringColor,
    );
    // White inner disc so the icon reads against the ring colour.
    canvas.drawCircle(
      centre,
      size / 2 - 12,
      Paint()..color = Colors.white,
    );
    // Icon glyph rendered as text using the icon's font.
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.55,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: iconColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2),
    );

    final image = await recorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _maybeFetchRoute() async {
    final order = _order;
    if (order == null) return;
    if (order.deliveryLatitude == null || order.deliveryLongitude == null) return;

    // Prefer the server-cached polyline. The backend refreshes it on rider GPS
    // pings, so subsequent `_order` updates from polling / websocket will keep
    // this fresh without any Directions API call from the client.
    final cached = order.routePolyline;
    if (cached != null && cached.isNotEmpty) {
      if (cached != _decodedPolylineCache) {
        final points = GoogleMapsService.decodePolyline(cached);
        if (!mounted) return;
        setState(() {
          _routePoints = points;
          _routeEtaSeconds = order.routeDurationSec;
          _decodedPolylineCache = cached;
        });
      } else if (order.routeDurationSec != _routeEtaSeconds) {
        setState(() => _routeEtaSeconds = order.routeDurationSec);
      }
      return;
    }

    // Fallback: server hasn't cached a route yet. Call Directions once per
    // order so the UI isn't empty. We only set the dedup lock on success —
    // otherwise a transient failure (e.g. API not enabled yet) would
    // permanently block the fetch until the app is relaunched.
    final rider = _riderLocation;
    if (rider == null) return;
    if (_directionsFallbackOrderId == order.publicId) return;
    final result = await GoogleMapsService.fetchDirections(
      LatLng(rider.latitude, rider.longitude),
      LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
    );
    if (!mounted || result == null) return;
    _directionsFallbackOrderId = order.publicId;
    setState(() {
      _routePoints = result.points;
      _routeEtaSeconds = result.durationSeconds;
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
      final result = await ApiService.trackOrder(code.trim().toUpperCase());
      setState(() {
        _order = result.order;
        // Seed rider location from the response so the map paints
        // immediately if the order is already out for delivery and the
        // server has a cached position. Otherwise the customer would
        // wait for the next WS ping (up to 10s, or never if rider is
        // stationary).
        if (result.riderLocation != null) {
          _riderLocation = result.riderLocation;
        }
        if (result.order.status == 'delivered') _deliveredBanner = true;
      });
      _maybeFetchRoute();
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        try {
          final updated = await ApiService.trackOrder(code.trim().toUpperCase());
          if (!mounted) return;
          setState(() {
            _order = updated.order;
            if (updated.riderLocation != null) {
              _riderLocation = updated.riderLocation;
            }
          });
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
            // Search box + Track button removed — this screen is only
            // ever opened from My Orders (initialCode is always
            // present), so manual code entry was just dead UI.
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (_order!.status == 'out_for_delivery' &&
                  (_order!.deliveryOtp ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  color: const Color(0xFF065F46),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'DELIVERY OTP',
                          style: TextStyle(
                            color: Colors.white70,
                            letterSpacing: 1.6,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _order!.deliveryOtp!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Share this with your rider to complete delivery.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (_order!.status == 'cancelled' &&
                  (_order!.cancellationReason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFFDECEA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFF5C2B8)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reason for cancellation',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _order!.cancellationReason!,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

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
                            Expanded(
                              child: Text(
                                _routeEtaSeconds != null
                                    ? 'Rider on the way — ETA ${(_routeEtaSeconds! / 60).ceil()} min'
                                    : 'Rider is on the way',
                                style: const TextStyle(
                                    color: AppColors.brandBlueDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ),
                            Text(_ageLabel(_riderLocation!.updatedAt),
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                        child: SizedBox(
                          height: 220,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(_riderLocation!.latitude, _riderLocation!.longitude),
                              zoom: 15,
                            ),
                            onMapCreated: (c) {
                              if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
                            },
                            markers: {
                              Marker(
                                markerId: const MarkerId('rider'),
                                position: LatLng(
                                    _riderLocation!.latitude, _riderLocation!.longitude),
                                // Custom scooter pin (orange ring + delivery
                                // glyph) once the bitmap has been built;
                                // falls back to the default coloured pin
                                // for the first frame so the marker isn't
                                // missing while we're rendering.
                                icon: _riderMarkerIcon ??
                                    BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueOrange),
                                anchor: const Offset(0.5, 0.5),
                                infoWindow: const InfoWindow(title: 'Rider'),
                              ),
                              if (_order!.deliveryLatitude != null &&
                                  _order!.deliveryLongitude != null)
                                Marker(
                                  markerId: const MarkerId('delivery'),
                                  position: LatLng(_order!.deliveryLatitude!,
                                      _order!.deliveryLongitude!),
                                  icon: _destinationMarkerIcon ??
                                      BitmapDescriptor.defaultMarkerWithHue(
                                          BitmapDescriptor.hueRed),
                                  anchor: const Offset(0.5, 0.5),
                                  infoWindow:
                                      const InfoWindow(title: 'Delivery'),
                                ),
                            },
                            polylines: _routePoints.isEmpty
                                ? {}
                                : {
                                    Polyline(
                                      polylineId: const PolylineId('route'),
                                      color: AppColors.brandBlue,
                                      width: 4,
                                      points: _routePoints,
                                    ),
                                  },
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            liteModeEnabled: false,
                            gestureRecognizers: {
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
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
                      ..._order!.items.map((item) {
                        final isRejected = item.isRejected;
                        final textStyle = TextStyle(
                          decoration: isRejected
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: isRejected ? Colors.grey : null,
                        );
                        final row = Row(children: [
                          Text(
                            '${item.quantity}× ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isRejected
                                  ? Colors.grey
                                  : AppColors.brandBlue,
                              decoration: textStyle.decoration,
                            ),
                          ),
                          Expanded(
                            child: Text(item.productName, style: textStyle),
                          ),
                          Text(
                            '₹${(item.lineTotalCents / 100).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: textStyle.decoration,
                              color: textStyle.color,
                            ),
                          ),
                        ]);
                        if (!isRejected) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: row,
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF5F5), Color(0xFFFFECEC)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0x59B3261E),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                row,
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0x59B3261E),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.close_rounded,
                                        size: 13,
                                        color: Color(0xFFB3261E),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Removed by store',
                                        style: TextStyle(
                                          color: Color(0xFFB3261E),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.rejectionReason != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Reason: ${item.rejectionReason}',
                                    style: const TextStyle(
                                      color: Color(0xFF8A3B36),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
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
