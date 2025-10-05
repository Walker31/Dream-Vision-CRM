// lib/models/user_model.dart

class User {
  final int id;
  final String username;
  final String firstName;
  final String role; // 'Admin', 'Counsellor', 'Telecaller', etc.

  User({
    required this.id,
    required this.username,
    required this.firstName,
    required this.role,
  });

  /// A factory constructor for creating a new User instance from a profile data map.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // Correctly access the nested user ID
      id: json['user']['id'],
      // Correctly access the nested username
      username: json['user']['username'],
      // Correctly access the nested first_name with the right key
      firstName: json['user']['first_name'],
      // Correctly access the role from the top level
      role: json['role'],
    );
  }
}