import 'dart:convert';

class FollowUpUser {
  final int? id;
  final String fullName;
  final String? role;

  FollowUpUser({required this.id, required this.fullName, this.role});

  factory FollowUpUser.fromJson(Map<String, dynamic> json) {
    return FollowUpUser(
      id: json['id'],
      fullName: json['full_name'] ?? 'Unknown User',
      role: json['role'],
    );
  }
}

class FollowUp {
  final int id;
  final String remarks;

  final String? statusBeforeFollowUpName;
  final String? statusAfterFollowUpName; // backend gives only name

  /// shim for UI compatibility: f.statusAfterFollowUp
  String? get statusAfterFollowUp => statusAfterFollowUpName;

  final String? nextFollowUpDate;
  final DateTime timestamp;
  final FollowUpUser? user;

  /// Always a safe map
  final Map<String, dynamic> academicDetailsDiscussed;

  final bool cnr;

  FollowUp({
    required this.id,
    required this.remarks,
    this.statusBeforeFollowUpName,
    this.statusAfterFollowUpName,
    this.nextFollowUpDate,
    required this.timestamp,
    this.user,
    required this.academicDetailsDiscussed,
    required this.cnr,
  });

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    dynamic academic = json['academic_details_discussed'];

    Map<String, dynamic> parsedAcademic = {};

    // --- SAFE PARSING ---
    if (academic is Map<String, dynamic>) {
      parsedAcademic = academic;
    } else if (academic is String && academic.trim().isNotEmpty) {
      try {
        parsedAcademic = jsonDecode(academic);
      } catch (_) {
        parsedAcademic = {};
      }
    }

    return FollowUp(
      id: json['id'] ?? 0,
      remarks: (json['remarks'] ?? '').toString().trim().isNotEmpty
          ? json['remarks']
          : 'No remarks provided.',
      statusBeforeFollowUpName: json['status_before_follow_up_name'],
      statusAfterFollowUpName: json['status_after_follow_up_name'],
      nextFollowUpDate: json['next_follow_up_date'],

      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),

      user: (json['user'] is Map) ? FollowUpUser.fromJson(json['user']) : null,

      academicDetailsDiscussed: parsedAcademic,
      cnr: json['cnr'] ?? false,
    );
  }
}
