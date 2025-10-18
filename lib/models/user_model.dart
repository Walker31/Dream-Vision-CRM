class User {
  final int profileId;
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
  final String? shift; // Can be null
  final String remarks;
  final String? dateOfResignation; // Can be null
  final String profilePicture;
  final String createdAt;
  final String updatedAt;
  final String? department; // Can be null
  final String? supervisor; // Can be null

  // A convenient getter to combine first and last names.
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
    this.shift,
    required this.remarks,
    this.dateOfResignation,
    required this.profilePicture,
    required this.createdAt,
    required this.updatedAt,
    this.department,
    this.supervisor,
  });

  /// A factory constructor for creating a new User instance from a profile data map.
  factory User.fromJson(Map<String, dynamic> json) {
    // Safely access nested 'user' object
    final userData = json['user'] as Map<String, dynamic>? ?? {};

    return User(
      profileId: json['id'] ?? 0,
      userId: userData['id'] ?? 0,
      username: userData['username'] ?? '',
      email: userData['email'] ?? '',
      firstName: userData['first_name'] ?? '',
      lastName: userData['last_name'] ?? '',
      role: json['role'] ?? 'N/A',
      staffId: json['staff_id'] ?? 'N/A',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      dateOfJoining: json['date_of_joining'] ?? '',
      status: json['status'] ?? 'Unknown',
      shift: json['shift'], // Directly assign, can be null
      remarks: json['remarks'] ?? '',
      dateOfResignation: json['date_of_resignation'], // Directly assign, can be null
      profilePicture: json['profile_picture'] ?? '',
      createdAt: json['created_on'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      department: json['department'], // Directly assign, can be null
      supervisor: json['supervisor'], // Directly assign, can be null
    );
  }
}
