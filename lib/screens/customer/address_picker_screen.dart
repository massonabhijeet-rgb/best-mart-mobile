import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/tokens.dart';

/// Result returned from [AddressPickerScreen.open]. Callers merge the fields
/// into their own checkout state.
class PickedAddress {
  final double latitude;
  final double longitude;
  final String addressLine;

  const PickedAddress({
    required this.latitude,
    required this.longitude,
    required this.addressLine,
  });
}

/// Full-screen in-app map picker. Pins to map center; the user pans the map
/// to adjust. Bottom panel collects flat / floor / landmark so we have a
/// usable street address alongside the GPS coords.
class AddressPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String initialAddressLine;
  final bool fetchCurrentLocationOnOpen;

  const AddressPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddressLine = '',
    this.fetchCurrentLocationOnOpen = false,
  });

  static Future<PickedAddress?> open(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    String initialAddressLine = '',
    bool fetchCurrentLocationOnOpen = false,
  }) {
    return Navigator.of(context).push<PickedAddress>(
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          initialAddressLine: initialAddressLine,
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
  final _addressCtrl = TextEditingController();
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
    _addressCtrl.text = widget.initialAddressLine;
    if (widget.fetchCurrentLocationOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCurrentLocation();
      });
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
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

  void _confirm() {
    Navigator.of(context).pop(PickedAddress(
      latitude: _pinned.latitude,
      longitude: _pinned.longitude,
      addressLine: _addressCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _addressCtrl.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Set delivery location'),
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
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _addressCtrl,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'Flat / house no., floor, street, landmark…',
                      filled: true,
                      fillColor: AppColors.pageBg,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.brMd,
                        borderSide: BorderSide(color: AppColors.borderSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.brMd,
                        borderSide: BorderSide(color: AppColors.borderSoft),
                      ),
                    ),
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
                      onPressed: canConfirm ? _confirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.borderSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.brMd,
                        ),
                      ),
                      child: const Text(
                        'Confirm delivery location',
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
