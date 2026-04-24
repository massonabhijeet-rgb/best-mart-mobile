import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../providers/home_provider.dart';
import '../../services/api.dart';
import '../../services/auth_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/bill_summary.dart';
import '../../widgets/checkout_deals.dart';
import '../../widgets/coupon_input.dart';
import '../../widgets/public_coupon_carousel.dart';
import 'address_picker_screen.dart';
import 'cart_provider.dart';
import 'track_order_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _payment = 'phonepe';
  bool _placing = false;
  String _error = '';
  double? _lat, _lng;
  List<SavedAddress> _savedAddresses = [];
  int? _selectedAddressId;
  final _paymentSectionKey = GlobalKey();

  final _payMethods = [
    {
      'value': 'phonepe',
      'label': 'PhonePe',
      'sub': 'Opens PhonePe directly via UPI',
      'icon': Icons.account_balance_wallet_outlined,
      'iconAsset': 'assets/payment-icons/phonepay.png',
    },
    {
      'value': 'gpay',
      'label': 'Google Pay',
      'sub': 'Opens GPay directly via UPI',
      'icon': Icons.account_balance_wallet_outlined,
      'iconAsset': 'assets/payment-icons/googlepay.png',
    },
    {
      'value': 'paytm',
      'label': 'Paytm',
      'sub': 'Opens Paytm directly via UPI',
      'icon': Icons.account_balance_wallet_outlined,
      'iconAsset': 'assets/payment-icons/paytm.png',
    },
    {
      'value': 'razorpay',
      'label': 'Card / Netbanking / Other UPI',
      'sub': 'Pay online via Razorpay',
      'icon': Icons.lock_outline,
    },
    {
      'value': 'upi',
      'label': 'UPI on Delivery',
      'sub': 'Pay the rider via UPI QR',
      'icon': Icons.qr_code_2,
    },
    {
      'value': 'card',
      'label': 'Credit / Debit Card on Delivery',
      'sub': 'Visa, Mastercard, RuPay',
      'icon': Icons.credit_card,
    },
    {
      'value': 'cash_on_delivery',
      'label': 'Cash on Delivery',
      'sub': 'Pay when the order arrives',
      'icon': Icons.payments_outlined,
    },
  ];

  static const Map<String, String> _upiAppMap = {
    'phonepe': 'phonepe',
    'gpay': 'google_pay',
    'paytm': 'paytm',
  };

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameCtrl.text = user.fullName ?? '';
      _phoneCtrl.text = user.phone ?? '';
      _emailCtrl.text = user.email;
      _loadSavedAddresses();
    }
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final addrs = await ApiService.getAddresses();
      if (!mounted) return;
      setState(() {
        _savedAddresses = addrs;
        if (addrs.isNotEmpty) {
          final best = addrs.reduce((a, b) => a.useCount >= b.useCount ? a : b);
          _applyAddress(best);
        }
      });
    } catch (_) {}
  }

  void _applyAddress(SavedAddress a) {
    setState(() {
      _selectedAddressId = a.id;
      _nameCtrl.text = a.fullName;
      _phoneCtrl.text = a.phone;
      _addressCtrl.text = a.deliveryAddress;
      _notesCtrl.text = a.deliveryNotes ?? '';
      _lat = a.latitude;
      _lng = a.longitude;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAddressPicker({
    required bool useCurrentLocation,
    bool clearFields = false,
  }) async {
    HapticFeedback.selectionClick();
    final picked = await AddressPickerScreen.open(
      context,
      initialLatitude: clearFields ? null : _lat,
      initialLongitude: clearFields ? null : _lng,
      initialAddressLine: clearFields ? '' : _addressCtrl.text,
      initialFullName: clearFields ? '' : _nameCtrl.text,
      initialPhone: clearFields ? '' : _phoneCtrl.text,
      initialNotes: clearFields ? '' : _notesCtrl.text,
      fetchCurrentLocationOnOpen: useCurrentLocation,
      savedAddresses: _savedAddresses,
      selectedSavedAddressId: _selectedAddressId,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _lat = picked.latitude;
      _lng = picked.longitude;
      _addressCtrl.text = picked.addressLine;
      _nameCtrl.text = picked.fullName;
      _phoneCtrl.text = picked.phone;
      _notesCtrl.text = picked.deliveryNotes ?? '';
      // If the user chose one of their saved addresses from the list below
      // the map, re-select it; otherwise treat the result as a fresh draft.
      _selectedAddressId = picked.savedAddressId;
    });
  }

  Map<String, dynamic> _paymentEntry() => _payMethods.firstWhere(
        (m) => m['value'] == _payment,
        orElse: () => {'label': _payment, 'icon': Icons.payment},
      );

  String _paymentLabel() => _paymentEntry()['label'] as String;

  IconData _paymentIcon() => _paymentEntry()['icon'] as IconData;

  String? _paymentIconAsset() => _paymentEntry()['iconAsset'] as String?;

  bool get _hasValidAddress =>
      _selectedAddressId != null ||
      (_addressCtrl.text.trim().isNotEmpty && _lat != null && _lng != null);

  // First chunk of the address (before the first comma) doubles as a short
  // "Home / Work / PG" style label for the sticky bar header.
  String get _selectedAddressLabel {
    final line = _addressCtrl.text.trim();
    if (line.isEmpty) return 'your address';
    final head = line.split(',').first.trim();
    return head.isEmpty ? line : head;
  }

  // Groups used in the payment bottom sheet. Order within each group mirrors
  // the `_payMethods` master list so defaults stay stable.
  static const List<String> _payOnlineValues = [
    'phonepe',
    'gpay',
    'paytm',
    'razorpay',
  ];
  static const List<String> _payOnDeliveryValues = [
    'upi',
    'card',
    'cash_on_delivery',
  ];

  Future<void> _openPaymentSheet() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final onlineTiles = _payMethods
            .where((m) => _payOnlineValues.contains(m['value']))
            .toList();
        final onDeliveryTiles = _payMethods
            .where((m) => _payOnDeliveryValues.contains(m['value']))
            .toList();
        Widget buildGroup(String title, List<Map<String, dynamic>> tiles) {
          return Container(
            margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                for (final p in tiles)
                  _PaymentTile(
                    label: p['label'] as String,
                    subtitle: p['sub'] as String,
                    icon: p['icon'] as IconData,
                    iconAsset: p['iconAsset'] as String?,
                    selected: _payment == p['value'],
                    onTap: () =>
                        Navigator.of(sheetContext).pop(p['value'] as String),
                  ),
              ],
            ),
          );
        }

        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select Payment Method',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.inkMuted),
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      buildGroup('Pay online', onlineTiles),
                      buildGroup('Pay on delivery', onDeliveryTiles),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && picked != _payment) {
      setState(() => _payment = picked);
    }
  }

  Future<void> _openCouponSheet() async {
    HapticFeedback.selectionClick();
    // Kick off the user-specific list as soon as the sheet opens; the
    // FutureBuilder inside the sheet shows a spinner until it resolves.
    final availableFuture = ApiService.getAvailableCoupons();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtrl) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Apply a coupon',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColors.inkMuted),
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.brMd,
                              border: Border.all(color: AppColors.borderSoft),
                            ),
                            child: const CouponInput(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.local_offer_outlined,
                                  size: 16, color: AppColors.inkMuted),
                              SizedBox(width: 6),
                              Text(
                                'AVAILABLE FOR YOU',
                                style: TextStyle(
                                  color: AppColors.inkMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FutureBuilder<List<Coupon>>(
                          future: availableFuture,
                          builder: (_, snap) {
                            if (snap.connectionState !=
                                ConnectionState.done) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final list = snap.data ?? const <Coupon>[];
                            if (list.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                                child: Text(
                                  'No coupons available for you right now. '
                                  'Check back later — or enter a code above '
                                  'if you have one.',
                                  style: TextStyle(
                                    color: AppColors.inkMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }
                            return PublicCouponCarousel(
                              coupons: list,
                              onApply: (code) async {
                                final ok = await context
                                    .read<CartProvider>()
                                    .applyCoupon(code);
                                if (ok && sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                return ok;
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static String _upiAppLabel(String app) {
    if (app == 'phonepe') return 'PhonePe';
    if (app == 'google_pay') return 'Google Pay';
    return 'Paytm';
  }

  // Standard Checkout (cards / netbanking / other UPI). Returns the three
  // razorpay_* fields the server needs to verify a successful payment.
  // If [reuseIntent] is passed, we skip creating a new Razorpay order and
  // reuse an existing one — used by the UPI-intent → widget fallback path.
  // If [preferredUpiApp] is set, the widget is configured to show ONLY that
  // UPI app (not a full menu), so the customer still sees one tap.
  Future<Map<String, String>> _runRazorpay({
    required int amountCents,
    Map<String, dynamic>? reuseIntent,
    String? preferredUpiApp,
  }) async {
    final intent =
        reuseIntent ?? await ApiService.createPaymentIntent(amountCents);
    final razorpay = Razorpay();
    final completer = Completer<Map<String, String>>();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse r) {
      if (completer.isCompleted) return;
      completer.complete({
        'razorpayOrderId': r.orderId ?? '',
        'razorpayPaymentId': r.paymentId ?? '',
        'razorpaySignature': r.signature ?? '',
      });
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (completer.isCompleted) return;
      completer.completeError(Exception(r.message ?? 'Payment failed'));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse _w) {
      // external wallet chosen; Razorpay will still emit success/error later.
    });
    final Map<String, dynamic> options = {
      'key': intent['keyId'],
      'order_id': intent['razorpayOrderId'],
      'amount': intent['amount'],
      'currency': intent['currency'] ?? 'INR',
      'name': 'BestMart',
      'description': 'Order payment',
      'prefill': {
        'name': _nameCtrl.text.trim(),
        'contact': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      },
      'theme': {'color': '#10b981'},
    };
    if (preferredUpiApp != null) {
      options['method'] = {
        'upi': true,
        'card': false,
        'netbanking': false,
        'wallet': false,
        'emi': false,
        'paylater': false,
      };
      options['config'] = {
        'display': {
          'blocks': {
            'upi_preferred': {
              'name': 'Pay via ${_upiAppLabel(preferredUpiApp)}',
              'instruments': [
                {'method': 'upi', 'flows': ['intent'], 'apps': [preferredUpiApp]},
              ],
            },
          },
          'sequence': ['block.upi_preferred'],
          'preferences': {'show_default_blocks': false},
        },
      };
    }
    razorpay.open(options);
    try {
      return await completer.future;
    } finally {
      razorpay.clear();
    }
  }

  Future<void> _placeOrder() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _addressCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name, phone and address are required.');
      return;
    }
    final cart = context.read<CartProvider>();
    if (cart.totalItems == 0) {
      setState(() => _error = 'Your cart is empty.');
      return;
    }
    setState(() {
      _placing = true;
      _error = '';
    });
    try {
      // phonepe / gpay / paytm: try Razorpay S2S UPI Intent API first
      // (direct app launch). If Razorpay rejects (e.g. S2S not enabled),
      // fall back to Standard Checkout with that UPI app pre-selected.
      // razorpay → Standard Checkout for cards / netbanking / other UPI.
      //
      // The BestMart order is only committed AFTER payment succeeds (or an
      // intent URL is ready) so a failed payment never leaves a stale
      // unpaid order behind.
      final preferredUpiApp = _upiAppMap[_payment];
      final isIntent = preferredUpiApp != null;
      final isWidget = _payment == 'razorpay';
      final isOnline = isIntent || isWidget;
      final wirePaymentMethod = isOnline ? 'razorpay' : _payment;

      Map<String, String>? rzp;
      String? intentLaunchUrl;
      String? pendingRazorpayOrderId;
      if (isWidget) {
        rzp = await _runRazorpay(amountCents: cart.grandTotalCents);
      } else if (isIntent) {
        final intent =
            await ApiService.createPaymentIntent(cart.grandTotalCents);
        final rzpOrderId = intent['razorpayOrderId'] as String?;
        final rzpAmount = (intent['amount'] as num?)?.toInt() ??
            cart.grandTotalCents;
        try {
          final launch = await ApiService.createUpiIntent(
            razorpayOrderId: rzpOrderId ?? '',
            amountCents: rzpAmount,
            upiApp: preferredUpiApp,
            contact: _phoneCtrl.text.trim(),
          );
          intentLaunchUrl = launch['intentUrl'] as String?;
          pendingRazorpayOrderId = rzpOrderId;
        } catch (_) {
          // S2S UPI unavailable — fall back to Standard Checkout with this
          // UPI app pre-selected. Reuse the SAME Razorpay order so we don't
          // double-charge on retry.
          rzp = await _runRazorpay(
            amountCents: cart.grandTotalCents,
            reuseIntent: intent,
            preferredUpiApp: preferredUpiApp,
          );
        }
      }

      final order = await ApiService.createOrder({
        'customerName': _nameCtrl.text.trim(),
        'customerPhone': _phoneCtrl.text.trim(),
        'customerEmail':
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'deliveryAddress': _addressCtrl.text.trim(),
        'deliveryNotes':
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'paymentMethod': wirePaymentMethod,
        'deliveryLatitude': _lat,
        'deliveryLongitude': _lng,
        'couponCode': cart.appliedCoupon?.code,
        'razorpayOrderId': rzp?['razorpayOrderId'] ?? pendingRazorpayOrderId,
        'razorpayPaymentId': rzp?['razorpayPaymentId'],
        'razorpaySignature': rzp?['razorpaySignature'],
        'items': cart.items.values
            .map((i) =>
                {'productId': i.product.uniqueId, 'quantity': i.quantity})
            .toList(),
      });

      if (intentLaunchUrl != null && intentLaunchUrl.isNotEmpty) {
        await launchUrl(
          Uri.parse(intentLaunchUrl),
          mode: LaunchMode.externalApplication,
        );
      }

      cart.clear();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TrackOrderScreen(initialCode: order.publicId),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final empty = cart.totalItems == 0;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(title: const Text('Checkout')),
      bottomNavigationBar: empty ? null : _StickyCheckoutBar(
        cart: cart,
        placing: _placing,
        onPlace: _placeOrder,
        paymentLabel: _paymentLabel(),
        onChangePayment: _openPaymentSheet,
        hasAddress: _hasValidAddress,
        addressLine: _addressCtrl.text,
        addressLabel: _selectedAddressLabel,
        paymentIcon: _paymentIcon(),
        paymentIconAsset: _paymentIconAsset(),
        onChangeAddress: _hasValidAddress
            ? () => _openAddressPicker(useCurrentLocation: false)
            : () => _openAddressPicker(
                  useCurrentLocation: true,
                  clearFields: true,
                ),
        onAddAddress: () => _openAddressPicker(
          useCurrentLocation: true,
          clearFields: true,
        ),
      ),
      body: empty
          ? const _EmptyCart()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _EtaHero(),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Your cart',
                    icon: Icons.shopping_bag_outlined,
                    trailing: _CountChip(count: cart.totalItems),
                    child: Column(
                      children: cart.items.values
                          .map((item) => _CartLine(item: item))
                          .toList(),
                    ),
                  ),
                  ..._buildDealsSection(cart),
                  const SizedBox(height: AppSpacing.md),
                  _CouponEntryCard(
                    onTap: _openCouponSheet,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Bill details',
                    icon: Icons.receipt_long_outlined,
                    child: BillSummary(cart: cart),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PaymentSummaryCard(
                    key: _paymentSectionKey,
                    label: _paymentLabel(),
                    icon: _paymentIcon(),
                    iconAsset: _paymentIconAsset(),
                    onChange: _openPaymentSheet,
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: AppRadius.brSm,
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(_error,
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildDealsSection(CartProvider cart) {
    final home = context.watch<HomeProvider>();
    final spot = home.spotlight;
    if (spot == null) return const [];
    final pool = <Product>[
      ...spot.offerProducts,
      ...spot.dailyEssentials,
      ...spot.moodPicks,
    ];
    final seen = <String>{};
    final unique = pool.where((p) => seen.add(p.uniqueId)).toList();
    final excluded = cart.items.keys.toSet();
    if (unique.where((p) => !excluded.contains(p.uniqueId)).isEmpty) {
      return const [];
    }
    return [
      const SizedBox(height: AppSpacing.md),
      CheckoutDeals(pool: unique, excludeIds: excluded),
    ];
  }

}

class _CartLine extends StatelessWidget {
  final CartItem item;
  const _CartLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final p = item.product;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.brSm,
            child: SizedBox(
              width: 48,
              height: 48,
              child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: p.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      memCacheHeight: 160,
                      errorWidget: (_, __, ___) => _imageFallback(),
                      placeholder: (_, __) => _imageFallback(),
                    )
                  : _imageFallback(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
                ),
                Text(
                  p.unitLabel,
                  style: const TextStyle(
                    color: AppColors.inkFaint,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${(p.priceCents / 100).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _Stepper(
            qty: item.quantity,
            onMinus: () => cart.remove(p.uniqueId),
            onPlus: () => cart.add(p),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() => Container(
        color: AppColors.sectionSky,
        child: const Icon(Icons.shopping_basket,
            size: 22, color: AppColors.brandBlue),
      );
}

class _Stepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _Stepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.brandBlue,
          borderRadius: AppRadius.brSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.remove, onMinus),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: Text(
                '$qty',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            _btn(Icons.add, onPlus),
          ],
        ),
      );

  Widget _btn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: AppShadow.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.brandBlue, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      );
}

class _CountChip extends StatelessWidget {
  final int count;
  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count item${count == 1 ? '' : 's'}',
        style: const TextStyle(
          color: AppColors.brandBlueDark,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _EtaHero extends StatelessWidget {
  const _EtaHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandBlue, AppColors.brandBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.brMd,
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.electric_bolt_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Express delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Arriving in 10–15 mins',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'FREE pkg',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? iconAsset;
  final VoidCallback onChange;
  const _PaymentSummaryCard({
    super.key,
    required this.label,
    required this.icon,
    this.iconAsset,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onChange,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconAsset != null
                      ? AppColors.surface
                      : AppColors.brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: iconAsset != null
                      ? Border.all(color: AppColors.borderSoft)
                      : null,
                ),
                child: iconAsset != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            iconAsset!,
                            fit: BoxFit.contain,
                            cacheWidth: 128,
                            errorBuilder: (_, __, ___) => Icon(icon,
                                color: AppColors.brandBlue, size: 20),
                          ),
                        ),
                      )
                    : Icon(icon, color: AppColors.brandBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Payment method',
                      style: TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Text(
                'Change',
                style: TextStyle(
                  color: AppColors.brandBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right,
                  color: AppColors.brandBlue, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final String? iconAsset;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    this.iconAsset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brMd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.brandBlue.withValues(alpha: 0.06)
                  : AppColors.surface,
              borderRadius: AppRadius.brMd,
              border: Border.all(
                color: selected ? AppColors.brandBlue : AppColors.borderSoft,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconAsset != null
                        ? AppColors.surface
                        : (selected
                            ? AppColors.brandBlue
                            : AppColors.brandBlue.withValues(alpha: 0.1)),
                    borderRadius: AppRadius.brSm,
                    border: iconAsset != null
                        ? Border.all(color: AppColors.borderSoft)
                        : null,
                  ),
                  child: iconAsset != null
                      ? ClipRRect(
                          borderRadius: AppRadius.brSm,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Image.asset(
                              iconAsset!,
                              fit: BoxFit.contain,
                              cacheWidth: 128,
                              errorBuilder: (_, __, ___) => Icon(
                                icon,
                                color: AppColors.brandBlue,
                                size: 20,
                              ),
                            ),
                          ),
                        )
                      : Icon(
                          icon,
                          color:
                              selected ? Colors.white : AppColors.brandBlue,
                          size: 20,
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: selected
                              ? AppColors.brandBlueDark
                              : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.inkFaint,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? AppColors.brandBlue : AppColors.inkFaint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
}

class _StickyCheckoutBar extends StatelessWidget {
  final CartProvider cart;
  final bool placing;
  final VoidCallback onPlace;
  final String paymentLabel;
  final IconData paymentIcon;
  final String? paymentIconAsset;
  final VoidCallback onChangePayment;
  final bool hasAddress;
  final String addressLine;
  final String addressLabel;
  final VoidCallback onChangeAddress;
  final VoidCallback onAddAddress;
  const _StickyCheckoutBar({
    required this.cart,
    required this.placing,
    required this.onPlace,
    required this.paymentLabel,
    required this.paymentIcon,
    required this.paymentIconAsset,
    required this.onChangePayment,
    required this.hasAddress,
    required this.addressLine,
    required this.addressLabel,
    required this.onChangeAddress,
    required this.onAddAddress,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.borderSoft),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DeliveryHeaderStrip(
              hasAddress: hasAddress,
              addressLabel: addressLabel,
              addressLine: addressLine,
              onTap: placing
                  ? () {}
                  : (hasAddress ? onChangeAddress : onAddAddress),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PayUsingButton(
                    label: paymentLabel,
                    icon: paymentIcon,
                    iconAsset: paymentIconAsset,
                    onTap: placing ? () {} : onChangePayment,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _PlaceOrderPill(
                      placing: placing,
                      hasAddress: hasAddress,
                      totalCents: cart.grandTotalCents,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (!hasAddress) {
                          onAddAddress();
                        } else {
                          onPlace();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryHeaderStrip extends StatelessWidget {
  final bool hasAddress;
  final String addressLabel;
  final String addressLine;
  final VoidCallback onTap;
  const _DeliveryHeaderStrip({
    required this.hasAddress,
    required this.addressLabel,
    required this.addressLine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandGreen.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasAddress
                      ? Icons.apartment_rounded
                      : Icons.add_location_alt_outlined,
                  color: AppColors.brandOrangeDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                        ),
                        children: [
                          const TextSpan(text: 'Delivering to '),
                          TextSpan(
                            text: hasAddress ? addressLabel : 'add address',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasAddress && addressLine.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        addressLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hasAddress ? 'Change' : 'Add',
                style: const TextStyle(
                  color: AppColors.brandGreenDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayUsingButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? iconAsset;
  final VoidCallback onTap;
  const _PayUsingButton({
    required this.label,
    required this.icon,
    required this.iconAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconAsset != null
                        ? AppColors.surface
                        : AppColors.brandBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: iconAsset != null
                        ? Border.all(color: AppColors.borderSoft)
                        : null,
                  ),
                  child: iconAsset != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Image.asset(
                              iconAsset!,
                              fit: BoxFit.contain,
                              cacheWidth: 96,
                              errorBuilder: (_, __, ___) => Icon(
                                icon,
                                color: AppColors.brandBlue,
                                size: 14,
                              ),
                            ),
                          ),
                        )
                      : Icon(icon, color: AppColors.brandBlue, size: 14),
                ),
                const SizedBox(width: 6),
                const Text(
                  'PAY USING',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 16,
                  color: AppColors.ink,
                ),
              ],
            ),
            const SizedBox(height: 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceOrderPill extends StatelessWidget {
  final bool placing;
  final bool hasAddress;
  final int totalCents;
  final VoidCallback onTap;
  const _PlaceOrderPill({
    required this.placing,
    required this.hasAddress,
    required this.totalCents,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = placing;
    final addMode = !hasAddress;
    final gradient = disabled
        ? [AppColors.inkFaint, AppColors.inkFaint]
        : addMode
            ? [AppColors.brandOrange, AppColors.brandOrangeDark]
            : [AppColors.brandGreen, AppColors.brandGreenDark];
    final shadowColor =
        addMode ? AppColors.brandOrange : AppColors.brandGreen;

    return SizedBox(
      height: 60,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: shadowColor.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: placing
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : addMode
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_location_alt_outlined,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Add a delivery address',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₹${(totalCents / 100).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    height: 1.1,
                                  ),
                                ),
                                const Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 0.6,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Text(
                              'Place Order',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
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

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: AppColors.inkFaint.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Your cart is empty',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Add some products to get started.',
                style: TextStyle(color: AppColors.inkFaint, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Browse products'),
              ),
            ],
          ),
        ),
      );
}
class _CouponEntryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CouponEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (_, cart, __) {
        final applied = cart.appliedCoupon;
        return Material(
          color: AppColors.surface,
          borderRadius: AppRadius.brMd,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brMd,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: applied != null
                      ? AppColors.brandGreen.withValues(alpha: 0.35)
                      : AppColors.borderSoft,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (applied != null
                              ? AppColors.brandGreen
                              : AppColors.brandBlue)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_offer_outlined,
                      color: applied != null
                          ? AppColors.brandGreen
                          : AppColors.brandBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          applied != null
                              ? 'Coupon ${applied.code} applied'
                              : 'Apply a coupon',
                          style: TextStyle(
                            color: applied != null
                                ? AppColors.brandGreenDark
                                : AppColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          applied != null
                              ? '− ₹${(applied.discountCents / 100).toStringAsFixed(0)} off · Tap to change'
                              : 'Save more on this order',
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.brandBlue, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
