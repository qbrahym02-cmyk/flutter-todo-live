/// إعدادات ثابتة للتطبيق.
///
/// كل ما في مجلد `remote/` في المستودع يُقرأ من هذا الرابط وقت التشغيل،
/// لذلك أي تعديل تدفعه (push) على GitHub يصل للتطبيق بدون إعادة تثبيت.
class AppConstants {
  static const String githubUser = 'qbrahym02-cmyk';
  static const String githubRepo = 'flutter-todo-live';
  static const String branch = 'main';

  static const String remoteBase =
      'https://raw.githubusercontent.com/$githubUser/$githubRepo/$branch/remote';

  static const String configUrl = '$remoteBase/config.json';
  static const String versionUrl = '$remoteBase/version.json';

  /// كم مرة نعيد فحص الإعدادات أثناء فتح التطبيق.
  static const Duration refreshInterval = Duration(minutes: 2);
}
