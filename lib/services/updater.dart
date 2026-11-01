import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';

/// معلومات آخر إصدار من `remote/version.json`
/// (يحدّثه GitHub Actions تلقائياً بعد كل بناء).
class VersionInfo {
  final int latestBuild;
  final int minSupportedBuild;
  final String versionName;
  final String apkUrl;
  final String notes;
  final String? sha256;

  VersionInfo.fromJson(Map<String, dynamic> j)
      : latestBuild = (j['latest_build'] as num?)?.toInt() ?? 0,
        minSupportedBuild = (j['min_supported_build'] as num?)?.toInt() ?? 0,
        versionName = j['version_name'] as String? ?? '',
        apkUrl = j['apk_url'] as String? ?? '',
        notes = j['notes'] as String? ?? '',
        sha256 = (j['sha256'] as String?)?.isEmpty ?? true
            ? null
            : j['sha256'] as String;
}

class Updater {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<int> currentBuild() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  static Future<VersionInfo?> fetchLatest() async {
    try {
      final uri = Uri.parse(
          '${AppConstants.versionUrl}?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return VersionInfo.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } catch (e) {
      debugPrint('Version check failed: $e');
      return null;
    }
  }

  /// يفحص وجود إصدار جديد ويعرض نافذة التحديث.
  /// [silent] = لا يعرض رسالة "أنت على آخر إصدار".
  static Future<void> check(BuildContext context, {bool silent = true}) async {
    if (!supported) {
      if (!silent && context.mounted) {
        _snack(context, 'نسخة الويب تتحدث تلقائياً عند إعادة تحميل الصفحة ✨');
      }
      return;
    }
    final latest = await fetchLatest();
    final current = await currentBuild();
    if (!context.mounted) return;
    if (latest == null || latest.apkUrl.isEmpty) {
      if (!silent) _snack(context, 'تعذّر فحص التحديثات');
      return;
    }
    if (latest.latestBuild <= current) {
      if (!silent) _snack(context, 'أنت على آخر إصدار ($current) ✅');
      return;
    }
    final forced = current < latest.minSupportedBuild;
    await showDialog(
      context: context,
      barrierDismissible: !forced,
      builder: (_) => _UpdateDialog(info: latest, forced: forced),
    );
  }

  static void _snack(BuildContext c, String msg) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
}

class _UpdateDialog extends StatefulWidget {
  final VersionInfo info;
  final bool forced;
  const _UpdateDialog({required this.info, required this.forced});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _status;
  bool _busy = false;

  void _start() {
    setState(() {
      _busy = true;
      _status = 'جاري التنزيل...';
      _progress = 0;
    });
    try {
      OtaUpdate()
          .execute(
        widget.info.apkUrl,
        destinationFilename: 'todo_live_${widget.info.latestBuild}.apk',
        sha256checksum: widget.info.sha256,
      )
          .listen((event) {
        if (!mounted) return;
        setState(() {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              _progress = (double.tryParse(event.value ?? '') ?? 0) / 100;
              _status = 'جاري التنزيل... ${event.value ?? 0}%';
            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              _progress = 1;
              _status = 'اضغط "تثبيت" في نافذة النظام لإكمال التحديث';
              _busy = false;
            default:
              _status = 'حدث خطأ: ${event.status.name} ${event.value ?? ''}';
              _busy = false;
          }
        });
      }, onError: (e) {
        if (!mounted) return;
        setState(() {
          _status = 'فشل التحديث: $e';
          _busy = false;
        });
      });
    } catch (e) {
      setState(() {
        _status = 'فشل التحديث: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: AlertDialog(
        icon: const Icon(Icons.system_update, size: 40),
        title: Text('إصدار جديد ${widget.info.versionName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.info.notes.isNotEmpty) Text(widget.info.notes),
            if (widget.forced)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('هذا التحديث إلزامي للاستمرار.',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (_progress != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
            ],
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          if (!widget.forced && !_busy)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً'),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.download),
            label: Text(_progress == null ? 'تحديث الآن' : 'إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
