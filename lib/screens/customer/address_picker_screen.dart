import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/models.dart';
import '../../services/google_maps_service.dart';
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

  final Completer<GoogleMapController> _mapCtrl = Completer();
  late LatLng _pinned;
  bool _locating = false;
  String? _locationError;
  // Debounces reverse-geocoding: we only fire once the camera stops moving.
  Timer? _geocodeDebounce;
  bool _reverseLoading = false;

  // When saved addresses exist we default to the list view (matches the
  // Zepto-style picker) and only flip to the map when the user explicitly
  // adds a new address. Without saved addresses the map is the only sensible
  // starting point.
  late String _mode; // 'list' | 'map'
  Position? _currentPosition;

  // Details-sheet initials are tracked separately from widget.initial* so
  // the "+ Add new address" entry can start blank while "Edit" on a saved
  // address starts prefilled with that address's data.
  late String _draftAddressLine;
  late String _draftFullName;
  late String _draftPhone;
  late String _draftNotes;
  // When non-null the next successful save should update this saved address
  // rather than create a new draft.
  int? _editingSavedAddressId;

  @override
  void initState() {
    super.initState();
    _pinned = LatLng(
      widget.initialLatitude ?? _fallbackCenter.latitude,
      widget.initialLongitude ?? _fallbackCenter.longitude,
    );
    _draftAddressLine = widget.initialAddressLine;
    _draftFullName = widget.initialFullName;
    _draftPhone = widget.initialPhone;
    _draftNotes = widget.initialNotes;
    _mode = (widget.savedAddresses.isNotEmpty &&
            !widget.fetchCurrentLocationOnOpen)
        ? 'list'
        : 'map';
    if (widget.fetchCurrentLocationOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCurrentLocation();
      });
    }
    if (_mode == 'list') {
      // Best-effort — we don't block the UI on the permission dialog, we just
      // populate distance badges if/when it resolves.
      _resolveCurrentPosition();
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _resolveCurrentPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      setState(() => _currentPosition = pos);
    } catch (_) {
      // Swallow — distance badges are purely decorative.
    }
  }

  void _switchToMap() {
    // "+ Add new address" — blank details sheet, no saved-id carryover.
    setState(() {
      _mode = 'map';
      _draftAddressLine = '';
      _draftFullName = '';
      _draftPhone = '';
      _draftNotes = '';
      _editingSavedAddressId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentLocation();
    });
  }

  void _switchToMapForEdit(SavedAddress a) {
    final target = LatLng(
      a.latitude ?? _pinned.latitude,
      a.longitude ?? _pinned.longitude,
    );
    setState(() {
      _mode = 'map';
      _pinned = target;
      _draftAddressLine = a.deliveryAddress;
      _draftFullName = a.fullName;
      _draftPhone = a.phone;
      _draftNotes = a.deliveryNotes ?? '';
      _editingSavedAddressId = a.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (a.latitude != null && a.longitude != null) {
        final c = await _mapCtrl.future;
        c.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
      }
    });
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
      final c = await _mapCtrl.future;
      await c.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
      _scheduleReverseGeocode(target);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = 'Could not fetch your location. Please try again.';
      });
    }
  }

  void _scheduleReverseGeocode(LatLng target) {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _reverseLoading = true);
      final address =
          await GoogleMapsService.reverseGeocode(target.latitude, target.longitude);
      if (!mounted) return;
      setState(() {
        _reverseLoading = false;
        if (address != null && address.isNotEmpty) {
          _draftAddressLine = address;
        }
      });
    });
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
        initialAddressLine: _draftAddressLine,
        initialFullName: _draftFullName,
        initialPhone: _draftPhone,
        initialNotes: _draftNotes,
        savedAddressId: _editingSavedAddressId,
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
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: Text(
          _mode == 'list'
              ? 'Select delivery location'
              : 'Pin your delivery location',
        ),
        leading: _mode == 'map' && widget.savedAddresses.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _mode = 'list'),
              )
            : null,
      ),
      body: _mode == 'list' ? _buildList() : _buildMap(),
    );
  }

  Widget _buildList() {
    final saved = widget.savedAddresses;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: _AddNewAddressRow(onTap: _switchToMap),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              'Your saved addresses',
              style: TextStyle(
                color: AppColors.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final a = saved[index];
              final isCurrent = widget.selectedSavedAddressId == a.id;
              final distanceKm = _distanceKmTo(a);
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
                  distanceKm: distanceKm,
                  onTap: () => _pickSaved(a),
                  onEdit: () => _switchToMapForEdit(a),
                ),
              );
            },
            childCount: saved.length,
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.md),
        ),
      ],
    );
  }

  double? _distanceKmTo(SavedAddress a) {
    final pos = _currentPosition;
    if (pos == null) return null;
    if (a.latitude == null || a.longitude == null) return null;
    final meters = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      a.latitude!,
      a.longitude!,
    );
    return meters / 1000.0;
  }

  Widget _buildMap() {
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * 0.55;
    return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: mapHeight,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _pinned,
                      zoom: 16,
                    ),
                    onMapCreated: (c) {
                      if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
                    },
                    onCameraMove: (pos) {
                      if (pos.target.latitude != _pinned.latitude ||
                          pos.target.longitude != _pinned.longitude) {
                        setState(() => _pinned = pos.target);
                      }
                    },
                    onCameraIdle: () => _scheduleReverseGeocode(_pinned),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.brandBlue, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_draftAddressLine.trim().isNotEmpty)
                              Text(
                                _draftAddressLine,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              '${_pinned.latitude.toStringAsFixed(5)}, ${_pinned.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_reverseLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.md),
          ),
        ],
      );
  }
}

class _AddNewAddressRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddNewAddressRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.brandBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'Add new address',
                  style: TextStyle(
                    color: AppColors.brandBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkFaint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  final SavedAddress address;
  final bool isCurrent;
  final double? distanceKm;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _SavedAddressTile({
    required this.address,
    required this.isCurrent,
    required this.distanceKm,
    required this.onTap,
    required this.onEdit,
  });

  String _formatDistance(double km) {
    if (km >= 100) return '${km.toStringAsFixed(0)} km';
    if (km >= 10) return '${km.toStringAsFixed(1)} km';
    return '${km.toStringAsFixed(2)} km';
  }

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
              _IconTile(isCurrent: isCurrent, distanceKm: distanceKm,
                  formatDistance: _formatDistance),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      address.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.deliveryAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Phone number: ${address.phone}',
                            style: const TextStyle(
                              color: AppColors.inkFaint,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onEdit,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.brandBlue,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: AppColors.brandBlue,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final bool isCurrent;
  final double? distanceKm;
  final String Function(double) formatDistance;
  const _IconTile({
    required this.isCurrent,
    required this.distanceKm,
    required this.formatDistance,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isCurrent
        ? AppColors.brandBlue.withValues(alpha: 0.12)
        : AppColors.brandOrange.withValues(alpha: 0.10);
    final fg = isCurrent ? AppColors.brandBlue : AppColors.brandOrangeDark;
    return Container(
      width: 76,
      height: 88,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCurrent ? Icons.home_rounded : Icons.location_on_rounded,
            color: fg,
            size: 34,
          ),
          const SizedBox(height: 6),
          if (isCurrent)
            const Text(
              "You're here",
              style: TextStyle(
                color: AppColors.brandBlueDark,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            )
          else if (distanceKm != null)
            Text(
              formatDistance(distanceKm!),
              style: const TextStyle(
                color: AppColors.brandOrangeDark,
                fontSize: 10,
                fontWeight: FontWeight.w900,
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
  // When editing a saved address we thread its id through so the picker
  // can return it and the checkout screen keeps treating the selection as
  // the same saved entry (rather than a brand-new draft).
  final int? savedAddressId;

  const _AddressDetailsSheet({
    required this.latitude,
    required this.longitude,
    required this.initialAddressLine,
    required this.initialFullName,
    required this.initialPhone,
    required this.initialNotes,
    this.savedAddressId,
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
        savedAddressId: widget.savedAddressId,
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
