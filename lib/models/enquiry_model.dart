class Enquiry {
  final int id;
  // final String? school; // REMOVED - This is redundant, use schoolName
  final String? schoolName;
  final List<dynamic> interactions;
  final List<dynamic> followUps;
  
  // 1. CRITICAL: Added academicPerformance
  final List<dynamic>? academicPerformance; 

  final Map<String, dynamic>? assignedToCounsellorDetails;
  final Map<String, dynamic>? assignedToTelecallerDetails;
  final String? currentStatusName;
  final String? sourceName;
  final String firstName;
  final String? middleName;
  final String? lastName;
  final String? dateOfBirth;
  final String phoneNumber;
  final String? email;
  final String? address;
  final int? pincode;
  final List<String> referredBy;
  final String? fatherPhoneNumber;
  final String? motherPhoneNumber;
  final String? fatherOccupation;
  final String? enquiringForStandard;
  final String? enquiringForBoard;
  final String? enquiringForExam;
  final String? leadTemperature;
  final String? totalFeesDecided;
  final int? installmentsAgreed;
  final bool isAdmissionConfirmed;
  final String? referral;
  final String createdAt;
  final String updatedAt;

  Enquiry({
    required this.id,
    // required this.school, // REMOVED
    required this.interactions,
    required this.followUps,
    this.academicPerformance, // Added to constructor
    required this.assignedToCounsellorDetails,
    required this.assignedToTelecallerDetails,
    required this.currentStatusName,
    required this.sourceName,
    required this.firstName,
    this.schoolName,
    this.middleName,
    this.lastName,
    this.dateOfBirth,
    required this.phoneNumber,
    this.email,
    this.address,
    this.pincode,
    required this.referredBy,
    this.fatherPhoneNumber,
    this.motherPhoneNumber,
    this.fatherOccupation,
    this.enquiringForStandard,
    this.enquiringForBoard,
    this.enquiringForExam,
    this.leadTemperature,
    this.totalFeesDecided,
    this.installmentsAgreed,
    required this.isAdmissionConfirmed,
    this.referral,
    required this.createdAt,
    required this.updatedAt,
  });

  /// ✅ Factory to create object from JSON
  factory Enquiry.fromJson(Map<String, dynamic> json) {
    return Enquiry(
      id: json['id'],
      // school: json['school'], // REMOVED
      interactions: json['interactions'] ?? [],
      followUps: json['follow_ups'] ?? [],

      // 1. CRITICAL: Added academic_performance from JSON
      academicPerformance: json['academic_performance'] as List<dynamic>?,

      assignedToCounsellorDetails:
          json['assigned_to_counsellor_details'] as Map<String, dynamic>?,
      assignedToTelecallerDetails:
          json['assigned_to_telecaller_details'] as Map<String, dynamic>?,
      currentStatusName: json['current_status_name'] as String?,
      sourceName: json['source_name'] as String?,
      firstName: json['first_name'],
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      phoneNumber: json['phone_number'],
      email: json['email'] as String?,
      address: json['address'] as String?,

      // 2. FIXED: Added 'as int?' for type safety
      pincode: json['pincode'] as int?, 

      referredBy: json['referred_by'] != null
          ? List<String>.from(json['referred_by'])
          : [],
      fatherPhoneNumber: json['father_phone_number'] as String?,
      motherPhoneNumber: json['mother_phone_number'] as String?,
      fatherOccupation: json['father_occupation'] as String?,
      enquiringForStandard: json['enquiring_for_standard'] as String?,
      enquiringForBoard: json['enquiring_for_board'] as String?,
      enquiringForExam: json['enquiring_for_exam'] as String?,
      leadTemperature: json['lead_temperature'] as String?,

      // 3. FIXED: Added 'as String?' for type safety
      totalFeesDecided: json['total_fees_decided'] as String?,
      schoolName: json['school_name'] as String?,

      // 4. FIXED: Added 'as int?' for type safety
      installmentsAgreed: json['installments_agreed'] as int?,

      isAdmissionConfirmed: json['is_admission_confirmed'] ?? false,
      referral: json['referral'] as String?,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  /// ✅ Convert object to JSON (useful if you need to send back)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // 'school': school, // REMOVED
      'school_name': schoolName,
      'interactions': interactions,
      'follow_ups': followUps,
      'academic_performance': academicPerformance, // Added
      'assigned_to_counsellor_details': assignedToCounsellorDetails,
      'assigned_to_telecaller_details': assignedToTelecallerDetails,
      'current_status_name': currentStatusName,
      'source_name': sourceName,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth,
      'phone_number': phoneNumber,
      'email': email,
      'address': address,
      'pincode': pincode,
      'referred_by': referredBy,
      'father_phone_number': fatherPhoneNumber,
      'mother_phone_number': motherPhoneNumber,
      'father_occupation': fatherOccupation,
      'enquiring_for_standard': enquiringForStandard,
      'enquiring_for_board': enquiringForBoard,
      'enquiring_for_exam': enquiringForExam,
      'lead_temperature': leadTemperature,
      'total_fees_decided': totalFeesDecided,
      'installments_agreed': installmentsAgreed,
      'is_admission_confirmed': isAdmissionConfirmed,
      'referral': referral,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}