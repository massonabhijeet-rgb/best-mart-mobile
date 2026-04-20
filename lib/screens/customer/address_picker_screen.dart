import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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

  const PickedAddress({
    required this.latitude,
    required this.longitude,
    required this.fullName,
    required this.phone,
    required this.addressLine,
    this.deliveryNotes,
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

  const AddressPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddressLine = '',
    this.initialFullName = '',
    this.initialPhone = '',
    this.initialNotes = '',
    this.fetchCurrentLocationOnOpen = false,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Pin your delivery location'),
      ),
      body: Column(
        children: [
          Expanded(
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
          SafeArea(
            top: false,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
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
                    child: ElevatedButton(
                      onPressed: _continueToDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.brMd,
                        ),
                      ),
                      child: const Text(
                        'Continue',
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
          ),
        ],
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
