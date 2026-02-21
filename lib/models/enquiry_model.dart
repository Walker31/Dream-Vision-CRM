class Enquiry {
  final int id;
  final String? schoolName;
  final List<dynamic> interactions;
  final List<dynamic> followUps;
  final List<dynamic>? academicPerformance;
  final List<Map<String, dynamic>> exams;

  final Map<String, dynamic>? assignedToTelecallerDetails;

  final Map<String, dynamic>? createdByDetails;
  final Map<String, dynamic>? updatedByDetails;

  final String? currentStatusName;
  final String? sourceName;
  
  // Lightweight serializer fields (flat names)
  final String? assignedToTelecallerName;

  final String firstName;
  final String? middleName;
  final String? lastName;
  final String? dateOfBirth;
  final String? phoneNumber;
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
  final String? nextFollowUp;

  Enquiry({
    required this.id,
    required this.interactions,
    required this.followUps,
    this.academicPerformance,
    this.exams = const [],
    required this.assignedToTelecallerDetails,
    this.createdByDetails,
    this.updatedByDetails,
    required this.currentStatusName,
    required this.sourceName,
    this.assignedToTelecallerName,
    required this.firstName,
    this.middleName,
    this.lastName,
    this.dateOfBirth,
    this.phoneNumber,
    this.nextFollowUp,
    this.email,
    this.address,
    this.schoolName,
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

  factory Enquiry.fromJson(Map<String, dynamic> json) {
    return Enquiry(
      id: json['id'] ?? 0,
      interactions: json['interactions'] ?? [],
      followUps: json['follow_ups'] ?? [],
      academicPerformance: json['academic_performance'],
      exams: (json['exams'] as List?)?.cast<Map<String, dynamic>>() ?? [],

      assignedToTelecallerDetails: json['assigned_to_telecaller_details'],

      createdByDetails: json['created_by_details'],
      updatedByDetails: json['updated_by_details'],

      currentStatusName: json['current_status_name'] as String?,
      sourceName: json['source_name'] as String?,
      
      // Handle both lightweight (flat names) and full serializers
      assignedToTelecallerName: json['assigned_to_telecaller_name'] as String?,

      firstName: json['first_name'] ?? 'Unknown',
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      schoolName: json['school_name'] as String?,

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
      totalFeesDecided: json['total_fees_decided'] as String?,
      installmentsAgreed: json['installments_agreed'] as int?,
      isAdmissionConfirmed: json['is_admission_confirmed'] ?? false,
      referral: json['referral'] as String?,

      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      nextFollowUp: json['next_follow_up'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_name': schoolName,
      'interactions': interactions,
      'follow_ups': followUps,
      'academic_performance': academicPerformance,
      'exams': exams,

      'assigned_to_telecaller_details': assignedToTelecallerDetails,

      'created_by_details': createdByDetails,
      'updated_by_details': updatedByDetails,

      'current_status_name': currentStatusName,
      'source_name': sourceName,
      'assigned_to_telecaller_name': assignedToTelecallerName,
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
