import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/snackbar_utils.dart';

class AlarmSetupScreen extends StatefulWidget {
  final bool showAsOnboarding; // true = show as full page, false = bottom sheet style
  const AlarmSetupScreen({super.key, this.showAsOnboarding = false});

  @override
  State<AlarmSetupScreen> createState() => _AlarmSetupScreenState();
}

class _AlarmSetupScreenState extends State<AlarmSetupScreen>
    with WidgetsBindingObserver {
  
  // Permission states
  bool _notifGranted = false;
  bool _exactAlarmGranted = false;
  bool _batteryOptimized = true; // true = BAD (is optimized = restricted)
  bool _fullScreenGranted = true; // default true for older Android
  bool _isLoading = true;
  String _deviceBrand = '';
  String _androidVersion = '';
  int _sdkVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
    _getDeviceInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check permissions when user comes back from Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAll();
    }
  }

  Future<void> _getDeviceInfo() async {
    if (!Platform.isAndroid) return;
    final info = await DeviceInfoPlugin().androidInfo;
    setState(() {
      _deviceBrand = info.manufacturer.toLowerCase();
      _androidVersion = info.version.release;
    });
  }

  Future<void> _checkAll() async {
    if (!Platform.isAndroid) {
      setState(() => _isLoading = false);
      return;
    }
    
    final notif = await Permission.notification.isGranted;
    final exact = await Permission.scheduleExactAlarm.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;

    // Android 14+ full screen intent check
    bool fsGranted = true;
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      _sdkVersion = info.version.sdkInt;
      if (_sdkVersion >= 34) {
        fsGranted = await Permission.systemAlertWindow.isGranted;
      }
    }

    if (mounted) {
      setState(() {
        _notifGranted = notif;
        _exactAlarmGranted = exact;
        _batteryOptimized = !battery; // isGranted means NOT optimized (good)
        _fullScreenGranted = fsGranted;
        _isLoading = false;
      });
    }
  }

  bool get _allGranted => _notifGranted && _exactAlarmGranted && !_batteryOptimized && _fullScreenGranted;

  // ---- Permission Request Methods ----

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
    await _checkAll();
  }

  Future<void> _requestExactAlarm() async {
    final status = await Permission.scheduleExactAlarm.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      await AppSettings.openAppSettings(type: AppSettingsType.alarm);
    }
    await _checkAll();
  }

  Future<void> _requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
    }
    await _checkAll();
  }

  Future<void> _requestFullScreenIntent() async {
    final status = await Permission.systemAlertWindow.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (!mounted) return;
      await _showDisplayOverAppsDialog();
    }
    await _checkAll();
  }

  Future<void> _showDisplayOverAppsDialog() {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Android may have restricted this permission.\n\n'
          'IMPORTANT - If the setting is greyed out (Restricted Setting):\n'
          '1. Go to phone Settings -> Apps -> FamCare\n'
          '2. Tap the 3 vertical dots (top right) ⠇\n'
          '3. Tap "Allow restricted settings"\n'
          '4. Enter your phone PIN/password\n\n'
          'Then to enable the permission:\n'
          '1. Scroll down to "Display over other apps"\n'
          '2. Turn it ON\n\n'
          'Without this, alarm screen won\'t show on lock screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => AppSettings.openAppSettings(),
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Open manufacturer-specific settings via Intent
  Future<void> _openManufacturerSettings() async {
    const platform = MethodChannel('com.famcare/settings');
    try {
      await platform.invokeMethod('openAutoStart');
    } catch (e) {
      // Fallback to app settings
      await AppSettings.openAppSettings();
    }
    await _checkAll();
  }

  bool get _showManufacturerStep {
    return _deviceBrand.contains('xiaomi') ||
        _deviceBrand.contains('redmi') ||
        _deviceBrand.contains('poco') ||
        _deviceBrand.contains('oppo') ||
        _deviceBrand.contains('realme') ||
        _deviceBrand.contains('vivo') ||
        _deviceBrand.contains('oneplus') ||
        _deviceBrand.contains('huawei') ||
        _deviceBrand.contains('honor');
  }

  String get _manufacturerStepTitle {
    if (_deviceBrand.contains('xiaomi') || _deviceBrand.contains('redmi') || _deviceBrand.contains('poco')) {
      return 'Xiaomi: Autostart Enable Karo';
    } else if (_deviceBrand.contains('oppo') || _deviceBrand.contains('realme')) {
      return 'OPPO/Realme: Background Activity Allow Karo';
    } else if (_deviceBrand.contains('vivo')) {
      return 'Vivo: Background App Refresh Allow Karo';
    } else if (_deviceBrand.contains('oneplus')) {
      return 'OnePlus: Battery Optimization Off Karo';
    } else if (_deviceBrand.contains('huawei') || _deviceBrand.contains('honor')) {
      return 'Huawei: Protected Apps Mein Add Karo';
    }
    return 'Background Permission Allow Karo';
  }

  String get _manufacturerStepDesc {
    if (_deviceBrand.contains('xiaomi') || _deviceBrand.contains('redmi') || _deviceBrand.contains('poco')) {
      return 'Settings → Apps → FamCare → Autostart → Enable\nYa Security App → Permissions → Autostart';
    } else if (_deviceBrand.contains('oppo') || _deviceBrand.contains('realme')) {
      return 'Settings → Battery → App Quick Freeze → FamCare OFF karo\nSettings → Apps → FamCare → Battery Saver → OFF';
    } else if (_deviceBrand.contains('vivo')) {
      return 'iManager → App Manager → FamCare → Allow Background Running';
    } else if (_deviceBrand.contains('oneplus')) {
      return 'Settings → Battery → Battery Optimization → FamCare → Don\'t Optimize';
    } else if (_deviceBrand.contains('huawei') || _deviceBrand.contains('honor')) {
      return 'Settings → Apps → FamCare → Battery → Allow Background Activity';
    }
    return 'Settings → Apps → FamCare → Battery → Unrestricted';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAsOnboarding
          ? null
          : AppBar(
              title: const Text('Alarm Setup',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showAsOnboarding) const SizedBox(height: 20),

              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _allGranted
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _allGranted ? LucideIcons.checkCircle2 : LucideIcons.bellRing,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _allGranted ? 'Sab sahi hai! ✅' : 'Alarm Setup Karo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _allGranted
                          ? 'Tumhare phone pe medicine alarms sahi se kaam karenge.'
                          : 'Medicine alarms sahi se bajne ke liye yeh permissions zaroori hain.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    if (_deviceBrand.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Device: ${_deviceBrand[0].toUpperCase()}${_deviceBrand.substring(1)} • Android $_androidVersion',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Permissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),

              // Step 1: Notifications
              _buildPermissionCard(
                stepNumber: '1',
                icon: LucideIcons.bell,
                title: 'Notifications Allow Karo',
                description: 'Medicine reminder notifications dikhne ke liye zaroori hai.',
                isGranted: _notifGranted,
                onTap: _notifGranted ? null : _requestNotification,
                buttonLabel: 'Allow Notification',
              ),

              const SizedBox(height: 12),

              // Step 2: Exact Alarm
              _buildPermissionCard(
                stepNumber: '2',
                icon: LucideIcons.alarmClock,
                title: 'Exact Alarm Permission',
                description: 'Alarm bilkul sahi time pe bajne ke liye — Android 12+ pe zaroori.',
                isGranted: _exactAlarmGranted,
                onTap: _exactAlarmGranted ? null : _requestExactAlarm,
                buttonLabel: 'Allow Exact Alarm',
              ),

              const SizedBox(height: 12),

              // Step 3: Battery Optimization
              _buildPermissionCard(
                stepNumber: '3',
                icon: LucideIcons.battery,
                title: 'Battery Restriction Hatao',
                description: 'Battery optimization ON rahne se phone alarm ko band kar deta hai background mein.',
                isGranted: !_batteryOptimized,
                onTap: !_batteryOptimized ? null : _requestBatteryOptimization,
                buttonLabel: 'Battery Settings Kholo',
              ),

              // Step 4: Full Screen Intent (Android 14+ only)
              if (_sdkVersion >= 34) ...[
                const SizedBox(height: 12),
                _buildPermissionCard(
                  stepNumber: '4',
                  icon: LucideIcons.monitor,
                  title: 'Full Screen Alarm Allow Karo',
                  description: 'Android 14+ pe alarm screen lock screen ke upar dikhne ke liye yeh permission zaroori hai.',
                  isGranted: _fullScreenGranted,
                  onTap: _fullScreenGranted ? null : _requestFullScreenIntent,
                  buttonLabel: 'Allow Full Screen',
                ),
              ],

              // Step 5: Manufacturer specific (only show if needed)
              if (_showManufacturerStep) ...[
                const SizedBox(height: 12),
                _buildPermissionCard(
                  stepNumber: '5',
                  icon: LucideIcons.smartphone,
                  title: _manufacturerStepTitle,
                  description: _manufacturerStepDesc,
                  isGranted: false, // Can't auto-detect this
                  isManual: true,
                  onTap: _openManufacturerSettings,
                  buttonLabel: 'Settings Kholo',
                ),
              ],

              const SizedBox(height: 24),

              // Refresh button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    await _checkAll();
                    if (mounted) {
                      AppSnackBar.showInfo(context, 'Permissions check ho gayi!');
                    }
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text('Status Refresh Karo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF0EA5E9)),
                    foregroundColor: const Color(0xFF0EA5E9),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Done button (only show in onboarding mode or when all granted)
              if (widget.showAsOnboarding || _allGranted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _allGranted
                        ? () => Navigator.pop(context)
                        : null,
                    icon: const Icon(LucideIcons.checkCircle2),
                    label: Text(_allGranted ? 'Setup Complete! Shuru Karo' : 'Pehle Permissions Do'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allGranted ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String stepNumber,
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    bool isManual = false,
    VoidCallback? onTap,
    required String buttonLabel,
  }) {
    final color = isGranted
        ? Colors.green
        : isManual
            ? Colors.orange
            : const Color(0xFF0EA5E9);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green.shade100 : Colors.grey.shade100,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number + icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isGranted
                              ? Colors.green.shade50
                              : isManual
                                  ? Colors.orange.shade50
                                  : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isGranted
                                  ? LucideIcons.checkCircle2
                                  : isManual
                                      ? LucideIcons.alertTriangle
                                      : LucideIcons.xCircle,
                              size: 12,
                              color: isGranted
                                  ? Colors.green
                                  : isManual
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isGranted ? 'Done' : isManual ? 'Manual' : 'Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isGranted
                                    ? Colors.green
                                    : isManual
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  if (!isGranted && onTap != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        icon: Icon(
                          isManual ? LucideIcons.externalLink : LucideIcons.settings,
                          size: 16,
                        ),
                        label: Text(buttonLabel, style: const TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
