import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/task.dart';
import '../services/remote_config.dart';
import '../services/task_store.dart';
import '../services/updater.dart';
import '../widgets/task_tile.dart';

enum Filter { all, active, done }

class HomeScreen extends StatefulWidget {
  final TaskStore store;
  final RemoteConfigService remote;
  const HomeScreen({super.key, required this.store, required this.remote});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  Priority _newPriority = Priority.normal;
  Filter _filter = Filter.all;
  String _version = '';

  TaskStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = '${i.version}+${i.buildNumber}');
    });
    // فحص التحديثات بعد أول إطار
    WidgetsBinding.instance.addPostFrameCallback((_) => Updater.check(context));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // كل مرة يرجع المستخدم للتطبيق نجلب آخر الإعدادات
    if (state == AppLifecycleState.resumed) widget.remote.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _add([String? text]) {
    store.add(text ?? _controller.text, priority: _newPriority);
    if (text == null) _controller.clear();
    setState(() => _newPriority = Priority.normal);
  }

  Future<void> _refresh() async {
    final changed = await widget.remote.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(changed ? 'وصلت إعدادات جديدة ✨' : 'كل شيء محدّث'),
      duration: const Duration(seconds: 1),
    ));
  }

  List<Task> _visible() {
    final all = store.tasks;
    return switch (_filter) {
      Filter.all => all,
      Filter.active => all.where((t) => !t.done).toList(),
      Filter.done => all.where((t) => t.done).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, widget.remote]),
      builder: (context, _) {
        final cfg = widget.remote.config;
        if (cfg.maintenance) return _Maintenance(message: cfg.maintenanceMessage, onRetry: _refresh);
        final scheme = Theme.of(context).colorScheme;
        final tasks = _visible();

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cfg.appTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (cfg.subtitle.isNotEmpty)
                  Text(cfg.subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'update') Updater.check(context, silent: false);
                  if (v == 'refresh') _refresh();
                  if (v == 'clear') store.clearCompleted();
                  if (v == 'about') _about(cfg);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'update',
                      child: ListTile(
                          leading: Icon(Icons.system_update),
                          title: Text('فحص التحديثات'))),
                  const PopupMenuItem(
                      value: 'refresh',
                      child: ListTile(
                          leading: Icon(Icons.cloud_sync),
                          title: Text('تحديث الإعدادات'))),
                  if (cfg.showClearCompleted)
                    const PopupMenuItem(
                        value: 'clear',
                        child: ListTile(
                            leading: Icon(Icons.cleaning_services),
                            title: Text('حذف المكتملة'))),
                  const PopupMenuItem(
                      value: 'about',
                      child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('حول التطبيق'))),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (cfg.announcement != null)
                  SliverToBoxAdapter(child: _AnnouncementBanner(a: cfg.announcement!)),
                if (cfg.showStats)
                  SliverToBoxAdapter(child: _Stats(store: store)),
                SliverToBoxAdapter(child: _input(cfg, scheme)),
                if (cfg.showSuggestions && cfg.suggestedTasks.isNotEmpty)
                  SliverToBoxAdapter(child: _suggestions(cfg)),
                SliverToBoxAdapter(child: _filters()),
                if (tasks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.task_alt,
                              size: 72, color: scheme.primary.withAlpha(90)),
                          const SizedBox(height: 12),
                          Text(
                            _filter == Filter.done
                                ? 'لا توجد مهام مكتملة بعد'
                                : 'لا توجد مهام — أضف أول مهمة 👆',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    sliver: SliverList.builder(
                      itemCount: tasks.length,
                      itemBuilder: (_, i) => TaskTile(
                        key: ValueKey(tasks[i].id),
                        task: tasks[i],
                        store: store,
                        showPriority: cfg.showPriority,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _input(RemoteConfig cfg, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                      hintText: 'أضف مهمة جديدة...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                if (cfg.showPriority)
                  PopupMenuButton<Priority>(
                    tooltip: 'الأولوية',
                    icon: Icon(Icons.flag, color: priorityColor(_newPriority)),
                    onSelected: (p) => setState(() => _newPriority = p),
                    itemBuilder: (_) => Priority.values
                        .map((p) => PopupMenuItem(
                              value: p,
                              child: Row(children: [
                                Icon(Icons.flag, color: priorityColor(p)),
                                const SizedBox(width: 8),
                                Text(priorityLabel(p)),
                              ]),
                            ))
                        .toList(),
                  ),
                IconButton.filled(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _suggestions(RemoteConfig cfg) => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: cfg.suggestedTasks
              .map((s) => Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text(s),
                      onPressed: () => _add(s),
                    ),
                  ))
              .toList(),
        ),
      );

  Widget _filters() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SegmentedButton<Filter>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: Filter.all, label: Text('الكل')),
            ButtonSegment(value: Filter.active, label: Text('الحالية')),
            ButtonSegment(value: Filter.done, label: Text('المكتملة')),
          ],
          selected: {_filter},
          onSelectionChanged: (s) => setState(() => _filter = s.first),
        ),
      );

  void _about(RemoteConfig cfg) {
    final last = widget.remote.lastFetched;
    showAboutDialog(
      context: context,
      applicationName: cfg.appTitle,
      applicationVersion: _version,
      applicationIcon: const Icon(Icons.task_alt, size: 40),
      children: [
        Text('نسخة الإعدادات البعيدة: ${cfg.configVersion}'),
        Text(last == null
            ? 'لم يتم الاتصال بالسيرفر بعد'
            : 'آخر مزامنة: ${TimeOfDay.fromDateTime(last).format(context)}'),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  final TaskStore store;
  const _Stats({required this.store});

  @override
  Widget build(BuildContext context) {
    final total = store.tasks.length;
    final done = store.doneCount;
    final ratio = total == 0 ? 0.0 : done / total;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        elevation: 0,
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(fit: StackFit.expand, children: [
                  CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 6,
                    backgroundColor: scheme.surface.withAlpha(120),
                  ),
                  Center(
                      child: Text('${(ratio * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أنجزت $done من $total',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      total == 0
                          ? 'ابدأ يومك بإضافة مهمة'
                          : done == total
                              ? 'رائع! أنهيت كل المهام 🎉'
                              : 'باقي ${total - done} مهام',
                      style: Theme.of(context).textTheme.bodySmall,
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

class _AnnouncementBanner extends StatelessWidget {
  final Announcement a;
  const _AnnouncementBanner({required this.a});

  @override
  Widget build(BuildContext context) {
    final fg = a.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: a.color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: a.url == null
              ? null
              : () => launchUrl(Uri.parse(a.url!),
                  mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.campaign, color: fg),
              const SizedBox(width: 8),
              Expanded(child: Text(a.text, style: TextStyle(color: fg))),
              if (a.url != null) Icon(Icons.open_in_new, size: 16, color: fg),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Maintenance extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _Maintenance({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.construction, size: 72),
              const SizedBox(height: 16),
              Text(message.isEmpty ? 'التطبيق تحت الصيانة' : message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ]),
          ),
        ),
      );
}
