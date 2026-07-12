class FamilyTaskComment {
  final String id;
  final String taskId;
  final String authorUserId;
  final String comment;
  final String? attachmentUrl;
  final DateTime createdAt;

  FamilyTaskComment({
    required this.id,
    required this.taskId,
    required this.authorUserId,
    required this.comment,
    this.attachmentUrl,
    required this.createdAt,
  });

  factory FamilyTaskComment.fromMap(Map<String, dynamic> map) {
    return FamilyTaskComment(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      authorUserId: map['author_user_id'] as String,
      comment: map['comment'] as String,
      attachmentUrl: map['attachment_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'author_user_id': authorUserId,
      'comment': comment,
      'attachment_url': attachmentUrl,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
