import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_live/models/task.dart';
import 'package:todo_live/services/remote_config.dart';
import 'package:todo_live/services/task_store.dart';

void main() {
  test('TaskStore add / toggle / clear', () async {
    SharedPreferences.setMockInitialValues({});
    final s = TaskStore();
    await s.load();
    s.add('مهمة 1', priority: Priority.high);
    s.add('  ');
    expect(s.tasks.length, 1);
    s.toggle(s.tasks.first);
    expect(s.doneCount, 1);
    s.clearCompleted();
    expect(s.tasks, isEmpty);
  });

  test('RemoteConfig parses json', () {
    final c = RemoteConfig.fromJson({
      'config_version': 3,
      'app_title': 'X',
      'primary_color': '#FF0000',
      'features': {'show_stats': false},
      'announcement': {'enabled': true, 'text': 'hi'},
    });
    expect(c.configVersion, 3);
    expect(c.showStats, false);
    expect(c.announcement?.text, 'hi');
    expect(c.primaryColor.toARGB32(), 0xFFFF0000);
  });
}
