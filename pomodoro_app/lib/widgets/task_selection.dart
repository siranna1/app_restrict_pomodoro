import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskSelection extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onTaskSelected;

  const TaskSelection({
    Key? key,
    required this.tasks,
    required this.onTaskSelected,
  }) : super(key: key);

  @override
  _TaskSelectionState createState() => _TaskSelectionState();
}

class _TaskSelectionState extends State<TaskSelection> {
  String _selectedCategory = 'すべて';
  Task? _selectedTask;

  @override
  Widget build(BuildContext context) {
    // カテゴリーリストを作成
    final categories = ['すべて', ...widget.tasks.map((e) => e.category).toSet()];

    // カテゴリーでフィルタリング
    final filteredTasks = _selectedCategory == 'すべて'
        ? widget.tasks
        : widget.tasks
            .where((task) => task.category == _selectedCategory)
            .toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'タスクを選択',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            // カテゴリー選択チップ
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = category;
                            _selectedTask = null;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // タスクリスト
            if (filteredTasks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('タスクがありません。新しいタスクを追加してください。'),
                ),
              )
            else
              Column(
                children: filteredTasks.map((task) {
                  final isSelected = _selectedTask?.id == task.id;
                  final progress = task.estimatedPomodoros > 0
                      ? task.completedPomodoros / task.estimatedPomodoros
                      : 0.0;

                  return Card(
                    elevation: isSelected ? 4 : 1,
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : null,
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTask = task;
                        });
                        widget.onTaskSelected(task);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(task.category),
                                  backgroundColor: Colors.grey[200],
                                ),
                              ],
                            ),
                            if (task.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                task.description,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 8),
                            // 予定ポモドーロ数が設定されている場合のみプログレスバーを表示
                            if (task.estimatedPomodoros > 0)
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: Colors.grey[300],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${task.completedPomodoros}/${task.estimatedPomodoros}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            if (task.estimatedPomodoros == 0)
                              Row(
                                children: [
                                  const Icon(Icons.timer,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${task.completedPomodoros} ポモドーロ完了',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
