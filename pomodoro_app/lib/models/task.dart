// models/task.dart - タスクモデル
class Task {
  final int? id;
  final String name;
  final String category;
  final String description;
  final int estimatedPomodoros;
  int completedPomodoros;
  final DateTime createdAt;
  DateTime updatedAt;
  final String? tickTickId;

  // Firebase同期用に追加
  String? firebaseId;
  bool isDeleted = false; // 論理削除フラグ

  Task({
    this.id,
    required this.name,
    required this.category,
    this.description = '',
    required this.estimatedPomodoros,
    this.completedPomodoros = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.tickTickId,
    this.firebaseId,
    this.isDeleted = false,
  })  : this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'estimatedPomodoros': estimatedPomodoros,
      'completedPomodoros': completedPomodoros,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tickTickId': tickTickId,
      'firebaseId': firebaseId,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      description: map['description'],
      estimatedPomodoros: map['estimatedPomodoros'],
      completedPomodoros: map['completedPomodoros'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      tickTickId: map['tickTickId'],
      firebaseId: map['firebaseId'],
      isDeleted: map['isDeleted'] == 1,
    );
  }

  Task copyWith({
    int? id,
    String? name,
    String? category,
    String? description,
    int? estimatedPomodoros,
    int? completedPomodoros,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? tickTickId,
    String? firebaseId,
    bool? isDeleted,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tickTickId: tickTickId ?? this.tickTickId,
      firebaseId: firebaseId ?? this.firebaseId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'estimatedPomodoros': estimatedPomodoros,
      'completedPomodoros': completedPomodoros,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tickTickId': tickTickId,
      'isDeleted': isDeleted,
    };
  }

  factory Task.fromFirebase(Map<String, dynamic> data) {
    return Task(
      name: data['name'],
      category: data['category'],
      description: data['description'],
      estimatedPomodoros: data['estimatedPomodoros'],
      completedPomodoros: data['completedPomodoros'],
      createdAt: DateTime.parse(data['createdAt']),
      updatedAt: DateTime.parse(data['updatedAt']),
      tickTickId: data['tickTickId'],
      isDeleted: data['isDeleted'] ?? false,
    );
  }
}
