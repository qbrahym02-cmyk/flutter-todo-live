import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/task_store.dart';

Color priorityColor(Priority p) => switch (p) {
      Priority.high => Colors.red,
      Priority.normal => Colors.orange,
      Priority.low => Colors.green,
    };

String priorityLabel(Priority p) => switch (p) {
      Priority.high => 'عالية',
      Priority.normal => 'متوسطة',
      Priority.low => 'منخفضة',
    };

class TaskTile extends StatelessWidget {
  final Task task;
  final TaskStore store;
  final bool showPriority;
  const TaskTile({
    super.key,
    required this.task,
    required this.store,
    required this.showPriority,
  });

  void _delete(BuildContext context) {
    final index = store.tasks.indexOf(task);
    store.remove(task);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('تم حذف "${task.title}"'),
        action: SnackBarAction(
            label: 'تراجع', onPressed: () => store.insertAt(index, task)),
      ));
  }

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: task.title);
    var p = task.priority;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('تعديل المهمة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl, autofocus: true),
            if (showPriority) ...[
              const SizedBox(height: 16),
              SegmentedButton<Priority>(
                showSelectedIcon: false,
                segments: Priority.values
                    .map((x) => ButtonSegment(
                        value: x, label: Text(priorityLabel(x))))
                    .toList(),
                selected: {p},
                onSelectionChanged: (s) => setS(() => p = s.first),
              ),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      store.update(task, ctrl.text, p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('d_${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
            color: scheme.error, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      onDismissed: (_) => _delete(context),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: ListTile(
          onTap: () => store.toggle(task),
          onLongPress: () => _edit(context),
          leading: Checkbox(
            value: task.done,
            shape: const CircleBorder(),
            onChanged: (_) => store.toggle(task),
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  decoration: task.done ? TextDecoration.lineThrough : null,
                  color: task.done ? scheme.outline : null,
                ),
            child: Text(task.title),
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (showPriority)
              Icon(Icons.flag, size: 18, color: priorityColor(task.priority)),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _edit(context),
            ),
          ]),
        ),
      ),
    );
  }
}
