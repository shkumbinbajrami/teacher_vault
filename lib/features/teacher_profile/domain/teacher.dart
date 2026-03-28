/// Row from `teachers` (linked to [userId] → `auth.users`).
class Teacher {
  const Teacher({
    required this.id,
    required this.userId,
    this.fullName,
    this.email,
    this.avatarUrl,
    this.bio,
    required this.isActive,
  });

  final String id;
  final String userId;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final bool isActive;

  factory Teacher.fromRow(Map<String, dynamic> row) {
    return Teacher(
      id: '${row['id']}',
      userId: '${row['user_id']}',
      fullName: row['full_name'] as String?,
      email: row['email'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String?,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}
