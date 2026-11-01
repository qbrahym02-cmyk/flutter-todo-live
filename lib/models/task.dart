enum Priority { low, normal, high }

class Task {
  final String id;
  String title;
  bool done;
  Priority priority;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    this.priority = Priority.normal,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'priority': priority.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        done: j['done'] as bool? ?? false,
        priority: Priority.values.firstWhere(
          (p) => p.name == j['priority'],
          orElse: () => Priority.normal,
        ),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );
}
