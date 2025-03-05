// screens/tasks_screen.dart - タスク管理画面
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  _TasksScreenState createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _selectedCategory = 'すべて';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

// 利用可能なカテゴリリストを作成
    final categories = [
      'すべて',
      ...taskProvider.tasks.map((t) => t.category).toSet().toList()
    ];

    // タスクをフィルタリング
    final filteredTasks = _filterTasks(taskProvider.tasks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('タスク管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: TaskSearchDelegate(taskProvider.tasks),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // フィルターチップ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const SizedBox(width: 8),
                ...categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // 検索バー
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'タスクを検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // タスクリスト
          Expanded(
            child: filteredTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'タスクがありません',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('新しいタスクを追加'),
                          onPressed: () => _showAddTaskDialog(context),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      return _buildTaskItem(context, task);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddTaskDialog(context),
      ),
    );
  }

  // タスク項目ウィジェット
  Widget _buildTaskItem(BuildContext context, Task task) {
    final progress = task.estimatedPomodoros > 0
        ? task.completedPomodoros / task.estimatedPomodoros
        : 0.0;

    return Dismissible(
      key: Key('task_${task.id}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: Text('「${task.name}」を削除しますか？'),
            actions: [
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('削除'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        taskProvider.deleteTask(task.id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${task.name}」を削除しました')),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: InkWell(
          onTap: () => _showTaskDetailDialog(context, task),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                Row(
                  children: [
                    if (task.estimatedPomodoros > 0)
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.grey[300],
                        ),
                      ),
                    if (task.estimatedPomodoros > 0) const SizedBox(width: 8),
                    if (task.estimatedPomodoros > 0)
                      Text(
                        '${task.completedPomodoros}/${task.estimatedPomodoros}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (task.estimatedPomodoros == 0)
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: Colors.grey),
                    if (task.estimatedPomodoros == 0)
                      Text(
                        '${task.completedPomodoros} ポモドーロ',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    if (task.estimatedPomodoros == 0) Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditTaskDialog(context, task),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // タスクをフィルタリング
  List<Task> _filterTasks(List<Task> tasks) {
    // フィルター適用
    List<Task> result = [];
    if (_selectedCategory == 'すべて') {
      result = List.from(tasks);
    } else {
      result =
          tasks.where((task) => task.category == _selectedCategory).toList();
    }

    // 検索クエリ適用
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((task) {
        return task.name.toLowerCase().contains(query) ||
            task.description.toLowerCase().contains(query) ||
            task.category.toLowerCase().contains(query);
      }).toList();
    }

    // ソート：最新の更新順
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return result;
  }

  // タスク追加ダイアログ
  Future<void> _showAddTaskDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String category = '';
    String description = '';
    int estimatedPomodoros = 1;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(// StatefulBuilder を追加
            builder: (context, setState) {
          return AlertDialog(
            title: const Text('新しいタスクを追加'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'タスク名',
                      ),
                      initialValue: name,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'タスク名を入力してください';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        name = value!;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'カテゴリー',
                      ),
                      initialValue: category,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'カテゴリーを入力してください';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        category = value!;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '説明（任意）',
                      ),
                      initialValue: description,
                      maxLines: 2,
                      onSaved: (value) {
                        description = value ?? '';
                      },
                    ),
                    const SizedBox(height: 16),
                    // 予定ポモドーロ数の部分を修正
                    Row(
                      children: [
                        const Expanded(
                          child: Text('予定ポモドーロ数'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            if (estimatedPomodoros > 0) {
                              setState(() {
                                // StatefulBuilder の setState を使用
                                estimatedPomodoros--;
                              });
                            }
                          },
                        ),
                        Text(
                          '$estimatedPomodoros',
                          style: const TextStyle(fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              // StatefulBuilder の setState を使用
                              estimatedPomodoros++;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: const Text('追加'),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();

                    final taskProvider =
                        Provider.of<TaskProvider>(context, listen: false);

                    final newTask = Task(
                      name: name,
                      category: category,
                      description: description,
                      estimatedPomodoros: estimatedPomodoros,
                    );

                    taskProvider.addTask(newTask);

                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  // タスク編集ダイアログ
  Future<void> _showEditTaskDialog(BuildContext context, Task task) async {
    final formKey = GlobalKey<FormState>();
    String name = task.name;
    String category = task.category;
    String description = task.description;
    int estimatedPomodoros = task.estimatedPomodoros;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('タスクを編集'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'タスク名',
                        ),
                        initialValue: name,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'タスク名を入力してください';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          name = value!;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'カテゴリー',
                        ),
                        initialValue: category,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'カテゴリーを入力してください';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          category = value!;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '説明（任意）',
                        ),
                        initialValue: description,
                        maxLines: 2,
                        onSaved: (value) {
                          description = value ?? '';
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('予定ポモドーロ数'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (estimatedPomodoros > 0) {
                                setState(() {
                                  estimatedPomodoros--;
                                });
                              }
                            },
                          ),
                          Text(
                            '$estimatedPomodoros',
                            style: const TextStyle(fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                estimatedPomodoros++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('キャンセル'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('削除'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  onPressed: () {
                    final taskProvider =
                        Provider.of<TaskProvider>(context, listen: false);
                    taskProvider.deleteTask(task.id!);
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('保存'),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();

                      final taskProvider =
                          Provider.of<TaskProvider>(context, listen: false);

                      final updatedTask = task.copyWith(
                        name: name,
                        category: category,
                        description: description,
                        estimatedPomodoros: estimatedPomodoros,
                        updatedAt: DateTime.now(),
                      );

                      taskProvider.updateTask(updatedTask);

                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // タスク詳細ダイアログ
  Future<void> _showTaskDetailDialog(BuildContext context, Task task) async {
    final progress = task.estimatedPomodoros > 0
        ? task.completedPomodoros / task.estimatedPomodoros
        : 0.0;

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(task.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  label: Text(task.category),
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(height: 16),
                if (task.description.isNotEmpty) ...[
                  const Text(
                    '説明:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(task.description),
                  const SizedBox(height: 16),
                ],
                const Text(
                  '進捗:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(height: 8),
                Text(
                  '${task.completedPomodoros} / ${task.estimatedPomodoros} ポモドーロ完了',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '作成日:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_formatDateTime(task.createdAt)),
                const SizedBox(height: 8),
                const Text(
                  '最終更新:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_formatDateTime(task.updatedAt)),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('閉じる'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('編集'),
              onPressed: () {
                Navigator.of(context).pop();
                _showEditTaskDialog(context, task);
              },
            ),
          ],
        );
      },
    );
  }

  // 日時のフォーマット
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// タスク検索デリゲート
class TaskSearchDelegate extends SearchDelegate<Task?> {
  final List<Task> tasks;

  TaskSearchDelegate(this.tasks);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return Center(
        child: Text(
          '検索キーワードを入力してください',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final results = tasks.where((task) {
      final queryLower = query.toLowerCase();
      return task.name.toLowerCase().contains(queryLower) ||
          task.description.toLowerCase().contains(queryLower) ||
          task.category.toLowerCase().contains(queryLower);
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Text(
          '「$query」に一致するタスクはありません',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final task = results[index];
        return ListTile(
          title: Text(task.name),
          subtitle: Text(task.category),
          onTap: () {
            close(context, task);
          },
        );
      },
    );
  }
}
