import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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
  String _payment = 'cash_on_delivery';
  String _slot = 'Express (2–4 hrs)';
  bool _placing = false;
  String _error = '';
  double? _lat, _lng;
  bool _fetchingLocation = false;
  List<SavedAddress> _savedAddresses = [];
  int? _selectedAddressId;

  final _slots = [
    {'value': 'Express (2–4 hrs)', 'label': 'Express', 'sub': '2–4 hrs', 'recommended': true},
    {'value': 'Morning (8–12)', 'label': 'Morning', 'sub': '8–12', 'recommended': false},
    {'value': 'Afternoon (12–4)', 'label': 'Afternoon', 'sub': '12–4', 'recommended': false},
    {'value': 'Evening (4–8)', 'label': 'Evening', 'sub': '4–8', 'recommended': false},
  ];
  final _payMethods = [
    {
      'value': 'cash_on_delivery',
      'label': 'Cash on Delivery',
      'sub': 'Pay when the order arrives',
      'icon': Icons.payments_outlined,
    },
    {
      'value': 'phonepe',
      'label': 'PhonePe',
      'sub': 'Opens PhonePe directly via UPI',
      'icon': Icons.account_balance_wallet_outlined,
    },
    {
      'value': 'gpay',
      'label': 'Google Pay',
      'sub': 'Opens GPay directly via UPI',
      'icon': Icons.account_balance_wallet_outlined,
    },
    {
      'value': 'paytm',
      'label': 'Paytm',
      'sub': 'Opens Paytm directly via UPI',
      'icon': Icons.account_balance_wallet_outlined,
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

  Future<void> _fetchLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied';
          _fetchingLocation = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
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
        'deliverySlot': _slot,
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
                  _Section(
                    title: 'Your cart',
                    icon: Icons.shopping_bag_outlined,
                    child: Column(
                      children: cart.items.values
                          .map((item) => _CartLine(item: item))
                          .toList(),
                    ),
                  ),
                  ..._buildDealsSection(cart),
                  const SizedBox(height: AppSpacing.md),
                  Consumer<HomeProvider>(
                    builder: (_, home, __) {
                      if (home.coupons.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.brMd,
                            border: Border.all(color: AppColors.borderSoft),
                            boxShadow: AppShadow.soft,
                          ),
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm),
                          child: PublicCouponCarousel(
                            coupons: home.coupons,
                            onApply: (code) =>
                                context.read<CartProvider>().applyCoupon(code),
                          ),
                        ),
                      );
                    },
                  ),
                  _Section(
                    title: 'Have another code?',
                    icon: Icons.local_offer_outlined,
                    child: const CouponInput(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Bill details',
                    icon: Icons.receipt_long_outlined,
                    child: BillSummary(cart: cart),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_savedAddresses.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _Section(
                      title: 'Deliver to',
                      icon: Icons.home_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _savedAddresses
                            .map((a) => _AddressTile(
                                  address: a,
                                  selected: _selectedAddressId == a.id,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _applyAddress(a);
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: _savedAddresses.isNotEmpty
                        ? 'Or enter a new address'
                        : 'Delivery details',
                    icon: Icons.person_outline,
                    child: Column(
                      children: [
                        _field(_nameCtrl, 'Full name', TextInputType.name),
                        _field(_phoneCtrl, 'Phone number', TextInputType.phone),
                        _field(_emailCtrl, 'Email (optional)',
                            TextInputType.emailAddress),
                        _field(_addressCtrl, 'Delivery address',
                            TextInputType.streetAddress,
                            maxLines: 2),
                        _field(_notesCtrl, 'Delivery notes (optional)',
                            TextInputType.text),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed:
                              _fetchingLocation ? null : _fetchLocation,
                          icon: _fetchingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location),
                          label: Text(_lat != null
                              ? 'Location captured ✓'
                              : 'Use my current location'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Delivery slot',
                    icon: Icons.schedule,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _slots
                          .map((s) => _SlotChip(
                                label: s['label'] as String,
                                subtitle: s['sub'] as String,
                                recommended: s['recommended'] as bool,
                                selected: _slot == s['value'],
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _slot = s['value'] as String);
                                },
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Payment method',
                    icon: Icons.payment,
                    child: Column(
                      children: _payMethods
                          .map((p) => _PaymentTile(
                                label: p['label'] as String,
                                subtitle: p['sub'] as String,
                                icon: p['icon'] as IconData,
                                selected: _payment == p['value'],
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(
                                      () => _payment = p['value'] as String);
                                },
                              ))
                          .toList(),
                    ),
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    TextInputType type, {
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: AppRadius.brMd),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
          ),
        ),
      );
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
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      );
}

class _SlotChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;
  const _SlotChip({
    required this.label,
    required this.subtitle,
    required this.recommended,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandBlue.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: selected ? AppColors.brandBlue : AppColors.borderSoft,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: selected ? AppColors.brandBlue : AppColors.inkFaint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: selected ? AppColors.brandBlueDark : AppColors.ink,
                    ),
                  ),
                  if (recommended) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Text(
                        'FASTEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.inkFaint,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PaymentTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentTile({
    required this.label,
    required this.subtitle,
    required this.icon,
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
                    color: selected
                        ? AppColors.brandBlue
                        : AppColors.brandBlue.withValues(alpha: 0.1),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : AppColors.brandBlue,
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
  const _StickyCheckoutBar({
    required this.cart,
    required this.placing,
    required this.onPlace,
  });

  int get _savedCents {
    final itemSavings = cart.items.values.fold<int>(0, (s, item) {
      final p = item.product;
      final orig = p.originalPriceCents;
      if (orig == null || orig <= p.priceCents) return s;
      return s + (orig - p.priceCents) * item.quantity;
    });
    final freeDelivery =
        cart.subtotalCents >= CartProvider.freeDeliveryThresholdCents;
    return itemSavings +
        cart.promoDiscountCents +
        cart.couponDiscountCents +
        (freeDelivery ? CartProvider.deliveryFeeCents : 0);
  }

  @override
  Widget build(BuildContext context) {
    final saved = _savedCents;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
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
            if (saved > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.savings_outlined,
                        color: AppColors.brandGreen, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Saving ₹${(saved / 100).toStringAsFixed(0)} on this order',
                      style: const TextStyle(
                        color: AppColors.brandGreenDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: placing
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          onPlace();
                        },
                  borderRadius: AppRadius.brMd,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: placing
                            ? [AppColors.inkFaint, AppColors.inkFaint]
                            : [AppColors.brandBlue, AppColors.brandBlueDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppRadius.brMd,
                      boxShadow: placing
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.brandBlue
                                    .withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Center(
                      child: placing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Place Order',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${(cart.grandTotalCents / 100).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 18),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  final SavedAddress address;
  final bool selected;
  final VoidCallback onTap;
  const _AddressTile({
    required this.address,
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
            duration: const Duration(milliseconds: 180),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? AppColors.brandBlue : AppColors.inkFaint,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: selected
                                    ? AppColors.brandBlueDark
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                          if (address.useCount > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                'Used ${address.useCount}x',
                                style: const TextStyle(
                                  color: AppColors.brandGreenDark,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${address.phone} · ${address.deliveryAddress}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkFaint,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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
