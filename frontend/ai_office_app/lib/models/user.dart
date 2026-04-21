class User {
  final int id;
  final String username;
  final String theme;

  const User({required this.id, required this.username, required this.theme});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id:       json['id']       ?? 0,
    username: json['username'] ?? '',
    theme:    json['theme']    ?? 'light',
  );
}
