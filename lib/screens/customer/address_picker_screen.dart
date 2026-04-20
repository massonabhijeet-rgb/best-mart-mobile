import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../theme/tokens.dart';

/// Result returned from [AddressPickerScreen.open]. The picker collects both
/// the pinned coordinate and the human-entered address details (name, phone,
/// flat/floor/landmark, optional notes) across a two-step flow — map first,
/// then a details modal — so checkout never needs a separate "Your details"
/// form.
class PickedAddress {
  final double latitude;
  final double longitude;
  final String fullName;
  final String phone;
  final String addressLine;
  final String? deliveryNotes;
  // Non-null when the user picked a pre-existing saved address from the list
  // under the map; the checkout screen uses this to re-select the saved entry
  // instead of treating the result as a brand-new draft.
  final int? savedAddressId;

  const PickedAddress({
    required this.latitude,
    required this.longitude,
    required this.fullName,
    required this.phone,
    required this.addressLine,
    this.deliveryNotes,
    this.savedAddressId,
  });
}

/// Full-screen in-app map picker. Pins to map center; the user pans the map
/// to adjust. On "Continue" we open a bottom sheet that collects the
/// flat/floor/landmark, name and phone — so the checkout page itself can
/// stay a pure address-selector with no extra form fields.
class AddressPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String initialAddressLine;
  final String initialFullName;
  final String initialPhone;
  final String initialNotes;
  final bool fetchCurrentLocationOnOpen;
  // Rendered as tappable tiles beneath the map so the user can skip the
  // map+form dance and reuse a prior address in one tap.
  final List<SavedAddress> savedAddresses;
  final int? selectedSavedAddressId;

  const AddressPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddressLine = '',
    this.initialFullName = '',
    this.initialPhone = '',
    this.initialNotes = '',
    this.fetchCurrentLocationOnOpen = false,
    this.savedAddresses = const [],
    this.selectedSavedAddressId,
  });

  static Future<PickedAddress?> open(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    String initialAddressLine = '',
    String initialFullName = '',
    String initialPhone = '',
    String initialNotes = '',
    bool fetchCurrentLocationOnOpen = false,
    List<SavedAddress> savedAddresses = const [],
    int? selectedSavedAddressId,
  }) {
    return Navigator.of(context).push<PickedAddress>(
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          initialAddressLine: initialAddressLine,
          initialFullName: initialFullName,
          initialPhone: initialPhone,
          initialNotes: initialNotes,
          fetchCurrentLocationOnOpen: fetchCurrentLocationOnOpen,
          savedAddresses: savedAddresses,
          selectedSavedAddressId: selectedSavedAddressId,
        ),
      ),
    );
  }

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  static const LatLng _fallbackCenter = LatLng(28.6139, 77.2090); // Delhi

  final _mapCtrl = MapController();
  late LatLng _pinned;
  bool _locating = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _pinned = LatLng(
      widget.initialLatitude ?? _fallbackCenter.latitude,
      widget.initialLongitude ?? _fallbackCenter.longitude,
    );
    if (widget.fetchCurrentLocationOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCurrentLocation();
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _locating = false;
          _locationError =
              'Location permission is required to use your current location.';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pinned = target;
        _locating = false;
      });
      _mapCtrl.move(target, 17);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = 'Could not fetch your location. Please try again.';
      });
    }
  }

  Future<void> _continueToDetails() async {
    final picked = await showModalBottomSheet<PickedAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _AddressDetailsSheet(
        latitude: _pinned.latitude,
        longitude: _pinned.longitude,
        initialAddressLine: widget.initialAddressLine,
        initialFullName: widget.initialFullName,
        initialPhone: widget.initialPhone,
        initialNotes: widget.initialNotes,
      ),
    );
    if (!mounted || picked == null) return;
    Navigator.of(context).pop(picked);
  }

  void _pickSaved(SavedAddress a) {
    Navigator.of(context).pop(
      PickedAddress(
        latitude: a.latitude ?? _pinned.latitude,
        longitude: a.longitude ?? _pinned.longitude,
        fullName: a.fullName,
        phone: a.phone,
        addressLine: a.deliveryAddress,
        deliveryNotes: a.deliveryNotes,
        savedAddressId: a.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Cap the map height so the saved-address list below always peeks — on
    // very tall screens we don't want the map to swallow everything.
    final mapHeight = screenHeight * 0.42;
    final saved = widget.savedAddresses;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Pin your delivery location'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: mapHeight,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: _pinned,
                      initialZoom: 16,
                      minZoom: 4,
                      maxZoom: 19,
                      onPositionChanged: (pos, _) {
                        final c = pos.center;
                        if (c.latitude != _pinned.latitude ||
                            c.longitude != _pinned.longitude) {
                          setState(() => _pinned = c);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.bestmart.mobile',
                      ),
                    ],
                  ),
                  // Center pin — overlay, not a Marker, so it stays fixed at
                  // the viewport centre while the user pans the map.
                  const IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 32),
                        child: Icon(
                          Icons.location_on,
                          color: AppColors.brandBlue,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'locate',
                      onPressed: _locating ? null : _fetchCurrentLocation,
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.brandBlue,
                      child: _locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: AppShadow.soft,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: AppColors.inkMuted),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Drag the map to move the pin',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.borderSoft),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.brandBlue, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_pinned.latitude.toStringAsFixed(5)}, ${_pinned.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_locationError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _locationError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _continueToDetails,
                      icon: const Icon(Icons.add_location_alt_outlined,
                          size: 18),
                      label: const Text(
                        'Use this location',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.brMd,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (saved.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(Icons.bookmark_border,
                        size: 16, color: AppColors.inkMuted),
                    SizedBox(width: 6),
                    Text(
                      'SAVED ADDRESSES',
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
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final a = saved[index];
                  final isCurrent = widget.selectedSavedAddressId == a.id;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: _SavedAddressTile(
                      address: a,
                      isCurrent: isCurrent,
                      onTap: () => _pickSaved(a),
                    ),
                  );
                },
                childCount: saved.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.md),
          ),
        ],
      ),
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  final SavedAddress address;
  final bool isCurrent;
  final VoidCallback onTap;
  const _SavedAddressTile({
    required this.address,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              color: isCurrent ? AppColors.brandBlue : AppColors.borderSoft,
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.brandBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandBlue
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'CURRENT',
                              style: TextStyle(
                                color: AppColors.brandBlueDark,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.deliveryAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.phone,
                      style: const TextStyle(
                        color: AppColors.inkFaint,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkFaint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressDetailsSheet extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String initialAddressLine;
  final String initialFullName;
  final String initialPhone;
  final String initialNotes;

  const _AddressDetailsSheet({
    required this.latitude,
    required this.longitude,
    required this.initialAddressLine,
    required this.initialFullName,
    required this.initialPhone,
    required this.initialNotes,
  });

  @override
  State<_AddressDetailsSheet> createState() => _AddressDetailsSheetState();
}

class _AddressDetailsSheetState extends State<_AddressDetailsSheet> {
  late final TextEditingController _addressCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: widget.initialAddressLine);
    _nameCtrl = TextEditingController(text: widget.initialFullName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _notesCtrl = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _addressCtrl.text.trim().isNotEmpty &&
      _nameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      PickedAddress(
        latitude: widget.latitude,
        longitude: widget.longitude,
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        addressLine: _addressCtrl.text.trim(),
        deliveryNotes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Address details',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close, color: AppColors.inkMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.brandBlue.withValues(alpha: 0.06),
                        borderRadius: AppRadius.brMd,
                        border: Border.all(
                          color: AppColors.brandBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: AppColors.brandBlue, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Pinned at ${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                color: AppColors.brandBlueDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _field(
                      _addressCtrl,
                      'Flat / house no., floor, landmark',
                      TextInputType.streetAddress,
                      maxLines: 2,
                    ),
                    _field(_nameCtrl, 'Full name', TextInputType.name),
                    _field(_phoneCtrl, 'Phone number', TextInputType.phone),
                    _field(
                      _notesCtrl,
                      'Delivery notes (optional)',
                      TextInputType.text,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _canSave ? _save : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.borderSoft,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.brMd,
                          ),
                        ),
                        child: const Text(
                          'Save delivery address',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
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
          textCapitalization: type == TextInputType.name
              ? TextCapitalization.words
              : TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: AppRadius.brMd),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
          ),
        ),
      );
}
