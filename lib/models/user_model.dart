class User {
  final int profileId;   // <-- NOW CORRECT FOR LOGIN ALSO
  final int userId;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String staffId;
  final String phoneNumber;
  final String address;
  final String dateOfJoining;
  final String status;
  final String remarks;
  final String? dateOfResignation;
  final String profilePicture;
  final String createdAt;
  final String updatedAt;

  String get fullName => '$firstName $lastName'.trim();

  User({
    required this.profileId,
    required this.userId,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.staffId,
    required this.phoneNumber,
    required this.address,
    required this.dateOfJoining,
    required this.status,
    required this.remarks,
    this.dateOfResignation,
    required this.profilePicture,
    required this.createdAt,
    required this.updatedAt,
  });

  String get name => '$firstName $lastName'.trim();

  /// Normal Profile JSON (from /users/profile/)
  factory User.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] as Map<String, dynamic>? ?? {};

    return User(
      profileId: json['id'] ?? 0,
      userId: userData['id'] ?? 0,
      username: userData['username'] ?? '',
      email: userData['email'] ?? '',
      firstName: userData['first_name'] ?? '',
      lastName: userData['last_name'] ?? '',
      role: json['role'] ?? 'N/A',
      staffId: json['staff_id'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      dateOfJoining: json['date_of_joining'] ?? '',
      status: json['status'] ?? '',
      remarks: json['remarks'] ?? '',
      dateOfResignation: json['date_of_resignation'],
      profilePicture: json['profile_picture'] ?? '',
      createdAt: json['created_on'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  /// Login response JSON (from /users/login/)
  factory User.fromLoginJson(Map<String, dynamic> json) {
    return User(
      profileId: json['profile_id'] ?? 0,  // <-- FIXED HERE
      userId: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      role: json['role'] ?? 'N/A',
      staffId: '',
      phoneNumber: '',
      address: '',
      dateOfJoining: '',
      status: '',
      remarks: '',
      dateOfResignation: null,
      profilePicture: '',
      createdAt: '',
      updatedAt: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': profileId,
      'user': {
        'id': userId,
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
      },
      'role': role,
      'staff_id': staffId,
      'phone_number': phoneNumber,
      'address': address,
      'date_of_joining': dateOfJoining,
      'status': status,
      'remarks': remarks,
      'date_of_resignation': dateOfResignation,
      'profile_picture': profilePicture,
      'created_on': createdAt,
      'updated_at': updatedAt,
    };
  }
}
