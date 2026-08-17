import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/teacher/student_controller.dart';
import '../../controllers/auth/auth_controller.dart';
import '../../models/distress_signal_model.dart';
import '../../services/distress_signal_service.dart';
import '../teacher/chat_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StudentController());
    final authController = Get.find<AuthController>();
    final profile = authController.profile.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.fullName ?? 'My Section'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => authController.signOut()),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(controller.errorMessage.value!, textAlign: TextAlign.center),
            ),
          );
        }

        final section = controller.section.value;

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section != null
                                  ? '${section.yearLevel ?? ''} — ${section.name}'.trim()
                                  : 'No section assigned',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('${controller.classmates.length} students in this section'),
                          ],
                        ),
                      ),
                      if (section != null)
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          tooltip: 'Open section chat',
                          onPressed: () => _openChat(section.id),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Emergency SOS entry point. Two send paths: over the app
              // (reuses the section's MessageController/chat pipeline so
              // it shows up in-thread like any other message) or over
              // plain SMS as a fallback when there's no data connection.
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'In an emergency, send an SOS with your location and status.',
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: section == null
                            ? null
                            : () => _showSosSheet(context, sectionId: section.id),
                        child: const Text('SOS'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Drill and emergency check-in features aren\'t available yet in this version.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Classmates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (controller.classmates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No classmates listed yet.'),
                )
              else
                ...controller.classmates.map(
                      (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(c.fullName),
                    trailing: c.schoolIdNumber == profile?.schoolIdNumber
                        ? const Chip(label: Text('You'))
                        : null,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// Opens the section chat. `Get.put(..., tag: sectionId)` inside
  /// ChatScreen means this is the same MessageController instance the
  /// SOS sheet posts through, so an "app" SOS shows up here too.
  void _openChat(String sectionId) {
    Get.to(
          () => Scaffold(
        appBar: AppBar(title: const Text('Section Chat')),
        body: ChatScreen(sectionId: sectionId),
      ),
    );
  }

  void _showSosSheet(BuildContext context, {required String sectionId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SosSheet(sectionId: sectionId),
    );
  }
}

class _SosSheet extends StatefulWidget {
  const _SosSheet({required this.sectionId});

  final String sectionId;

  @override
  State<_SosSheet> createState() => _SosSheetState();
}

enum _SosChannel { sms, app }

class _SosSheetState extends State<_SosSheet> {
  final _formKey = GlobalKey<FormState>();

  // Most fields are user-typed for now, per the original TODO. Code
  // defaults from the signed-in student's profile but stays editable
  // in case someone is reporting for a classmate. Lat/lng is the one
  // auto-filled value (from device location) since retyping
  // coordinates during an emergency isn't realistic.
  late final TextEditingController _codeController;
  // The number this SOS's SMS gets sent TO — not the student's own
  // number, and there's no sensible default for it (it depends on
  // who's monitoring), so it's left blank for the student to type.
  final _mobileController = TextEditingController();
  final _latLngController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _messageController = TextEditingController();

  bool _sendingApp = false;
  bool _locating = false;
  String? _locationError;

  // Which channel is currently selected in the toggle below. Drives
  // which extra fields are shown/asked for and which single send
  // action is wired to the bottom button. Mobile number is only
  // relevant to the SMS path — the app path (createSignal) doesn't
  // use it — so it's only built (and therefore only validated) when
  // this is .sms.
  _SosChannel _channel = _SosChannel.sms;

  final _distressSignalService = DistressSignalService();

  @override
  void initState() {
    super.initState();
    final profile = Get.find<AuthController>().profile.value;
    _codeController = TextEditingController(text: profile?.schoolIdNumber ?? '');
    _fetchLocation();
  }

  /// Auto-fills lat/lng from the device's current position so the
  /// student doesn't have to type coordinates in a panic. The field
  /// stays editable — if location is unavailable/denied, or is wrong
  /// (e.g. stale indoors), they can still type or correct it manually.
  Future<void> _fetchLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location services are off';
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission denied';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission permanently denied — enable it in Settings';
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      _latLngController.text =
      '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      if (!mounted) return;
      // Non-fatal — the field just stays empty/editable so they can
      // type coordinates themselves.
      _locationError = e is String ? e : 'Could not get your location';
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _mobileController.dispose();
    _latLngController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// SOS|code_or_school_id|mobile|lat,lng|building|floor|message
  String _buildSosText() {
    return [
      'SOS',
      _codeController.text.trim(),
      _latLngController.text.trim(),
      _buildingController.text.trim(),
      _floorController.text.trim(),
      _messageController.text.trim(),
    ].join('|');
  }

  Future<void> _sendViaSms() async {
    if (!_formKey.currentState!.validate()) return;
    final uri = Uri(
      scheme: 'sms',
      path: _mobileController.text.trim(),
      queryParameters: {'body': _buildSosText()},
    );
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the SMS app.')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Parses the "lat,lng" field into separate doubles for createSignal's
  /// typed latitude/longitude params. Returns null (rather than
  /// throwing) on anything unparsable, so a malformed manual entry just
  /// omits location instead of blocking the whole SOS.
  (double, double)? _parseLatLng() {
    final parts = _latLngController.text.trim().split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }

  /// Inserts a row into `distress_signals` via
  /// DistressSignalService.createSignal — channel 'app' — instead of
  /// posting a chat message. Requires an active drill event because
  /// createSignal's drillEventId is non-nullable in the current schema;
  /// if none is running, that's surfaced rather than silently failing
  /// or mis-filing the signal against nothing.
  Future<void> _sendViaApp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sendingApp = true);
    try {
      final drillEventId = await _distressSignalService.fetchActiveDrillEventId();
      if (drillEventId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active drill right now — use "Send via SMS" instead.'),
            ),
          );
        }
        return;
      }

      final profile = Get.find<AuthController>().profile.value;
      final latLng = _parseLatLng();

      // rosterId isn't resolvable from what StudentHomeScreen has on
      // hand (the profile model shared with me has no rosterId field)
      // — studentName covers createSignal's "at least one of
      // rosterId/studentName" requirement. Swap in profile?.rosterId
      // here if/when that field exists, for a precise roster match
      // instead of a name string.
      await _distressSignalService.createSignal(
        drillEventId: drillEventId,
        channel: DistressChannel.app,
        studentName: profile?.fullName ?? _codeController.text.trim(),
        latitude: latLng?.$1,
        longitude: latLng?.$2,
        building: _buildingController.text.trim(),
        floor: _floorController.text.trim(),
        message: _messageController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingApp = false);
    }
  }

  static const _fieldSpacing = SizedBox(height: 14);

  InputDecoration _decoration(String label, {String? hint, IconData? icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    // DraggableScrollableSheet + SingleChildScrollView instead of a
    // plain Column: the sheet's height is capped, so once the on-screen
    // keyboard shows (or a field like this gets longer with the new
    // mobile number field) content scrolls instead of overflowing the
    // fixed-size box the modal gives it.
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.red.shade50,
                      child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Send SOS',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'This will be sent immediately — double check your details.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),

                Text('Send via', style: Theme.of(context).textTheme.labelLarge),
                _fieldSpacing,
                SegmentedButton<_SosChannel>(
                  segments: const [
                    ButtonSegment(
                      value: _SosChannel.sms,
                      label: Text('SMS'),
                      icon: Icon(Icons.sms_outlined),
                    ),
                    ButtonSegment(
                      value: _SosChannel.app,
                      label: Text('App'),
                      icon: Icon(Icons.send_outlined),
                    ),
                  ],
                  selected: {_channel},
                  onSelectionChanged: (s) => setState(() => _channel = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Colors.red.shade700,
                    selectedForegroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),
                Text('Your details', style: Theme.of(context).textTheme.labelLarge),
                _fieldSpacing,
                TextFormField(
                  controller: _codeController,
                  decoration: _decoration('School ID number', icon: Icons.badge_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 20),
                Text('Location', style: Theme.of(context).textTheme.labelLarge),
                _fieldSpacing,
                TextFormField(
                  controller: _latLngController,
                  decoration: _decoration(
                    'Latitude,Longitude',
                    hint: '14.568488,121.076232',
                    icon: Icons.my_location,
                    suffix: IconButton(
                      icon: _locating
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : const Icon(Icons.refresh),
                      tooltip: 'Refresh location',
                      onPressed: _locating ? null : _fetchLocation,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 6),
                Text(
                  _locating
                      ? 'Getting your location…'
                      : _locationError != null
                      ? '$_locationError — enter manually or retry'
                      : 'Auto-filled from your current location',
                  style: TextStyle(
                    fontSize: 12,
                    color: _locationError != null ? Colors.red.shade700 : Colors.grey.shade600,
                  ),
                ),
                _fieldSpacing,
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buildingController,
                        decoration: _decoration('Building', icon: Icons.apartment_outlined),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _floorController,
                        decoration: _decoration('Floor', icon: Icons.stairs_outlined),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Text('What\'s happening?', style: Theme.of(context).textTheme.labelLarge),
                _fieldSpacing,
                TextFormField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: _decoration(
                    'Describe your situation',
                    hint: "Trapped near the stairwell, can't move",
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                // Only asked for on the SMS path — this is the number
                // the SMS gets sent to, not anything about the app
                // path, which doesn't use a phone number at all.
                if (_channel == _SosChannel.sms) ...[
                  const SizedBox(height: 20),
                  Text('Send SMS to', style: Theme.of(context).textTheme.labelLarge),
                  _fieldSpacing,
                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: _decoration(
                      'Mobile number',
                      icon: Icons.contact_phone_outlined,
                      hint: '09171234567',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _sendingApp
                        ? null
                        : (_channel == _SosChannel.sms ? _sendViaSms : _sendViaApp),
                    icon: _sendingApp
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Icon(_channel == _SosChannel.sms ? Icons.sms_outlined : Icons.send),
                    label: Text(_channel == _SosChannel.sms ? 'Send via SMS' : 'Send via App'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}