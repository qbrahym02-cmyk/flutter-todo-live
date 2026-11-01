import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// الإعدادات التي تتحكم فيها عن بعد من ملف `remote/config.json`.
class RemoteConfig {
  final int configVersion;
  final String appTitle;
  final String subtitle;
  final Color primaryColor;
  final ThemeMode themeMode;
  final Announcement? announcement;
  final bool showStats;
  final bool showPriority;
  final bool showSuggestions;
  final bool showClearCompleted;
  final List<String> suggestedTasks;
  final bool maintenance;
  final String maintenanceMessage;

  const RemoteConfig({
    this.configVersion = 0,
    this.appTitle = 'مهامي',
    this.subtitle = 'نظّم يومك خطوة بخطوة',
    this.primaryColor = const Color(0xFF6750A4),
    this.themeMode = ThemeMode.system,
    this.announcement,
    this.showStats = true,
    this.showPriority = true,
    this.showSuggestions = true,
    this.showClearCompleted = true,
    this.suggestedTasks = const [],
    this.maintenance = false,
    this.maintenanceMessage = '',
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> j) {
    final f = (j['features'] as Map?)?.cast<String, dynamic>() ?? {};
    final m = (j['maintenance'] as Map?)?.cast<String, dynamic>() ?? {};
    final a = (j['announcement'] as Map?)?.cast<String, dynamic>();
    return RemoteConfig(
      configVersion: (j['config_version'] as num?)?.toInt() ?? 0,
      appTitle: j['app_title'] as String? ?? 'مهامي',
      subtitle: j['subtitle'] as String? ?? '',
      primaryColor: parseColor(j['primary_color']) ?? const Color(0xFF6750A4),
      themeMode: switch (j['theme_mode']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      announcement: (a != null && a['enabled'] == true)
          ? Announcement.fromJson(a)
          : null,
      showStats: f['show_stats'] as bool? ?? true,
      showPriority: f['show_priority'] as bool? ?? true,
      showSuggestions: f['show_suggestions'] as bool? ?? true,
      showClearCompleted: f['show_clear_completed'] as bool? ?? true,
      suggestedTasks:
          (j['suggested_tasks'] as List?)?.map((e) => '$e').toList() ?? [],
      maintenance: m['enabled'] as bool? ?? false,
      maintenanceMessage: m['message'] as String? ?? '',
    );
  }
}

class Announcement {
  final String text;
  final Color color;
  final String? url;

  const Announcement({required this.text, required this.color, this.url});

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        text: j['text'] as String? ?? '',
        color: parseColor(j['color']) ?? Colors.amber,
        url: (j['url'] as String?)?.isEmpty ?? true ? null : j['url'] as String,
      );
}

Color? parseColor(dynamic v) {
  if (v is! String) return null;
  var hex = v.replaceAll('#', '').trim();
  if (hex.length == 6) hex = 'FF$hex';
  final n = int.tryParse(hex, radix: 16);
  return n == null ? null : Color(n);
}

/// يجلب الإعدادات من GitHub، ويحفظ آخر نسخة ناجحة للعمل بدون إنترنت.
class RemoteConfigService extends ChangeNotifier {
  static const _cacheKey = 'remote_config_cache';
  RemoteConfig _config = const RemoteConfig();
  DateTime? lastFetched;
  Timer? _timer;

  RemoteConfig get config => _config;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        _config = RemoteConfig.fromJson(jsonDecode(cached));
      } catch (_) {}
    }
    notifyListeners();
    unawaited(refresh());
    _timer = Timer.periodic(AppConstants.refreshInterval, (_) => refresh());
  }

  /// يرجع true إذا وصلت إعدادات جديدة.
  Future<bool> refresh() async {
    try {
      final uri = Uri.parse(
          '${AppConstants.configUrl}?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final body = utf8.decode(res.bodyBytes);
      final next = RemoteConfig.fromJson(jsonDecode(body));
      lastFetched = DateTime.now();
      final changed = next.configVersion != _config.configVersion;
      _config = next;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, body);
      notifyListeners();
      return changed;
    } catch (e) {
      debugPrint('RemoteConfig refresh failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
