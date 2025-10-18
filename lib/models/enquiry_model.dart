class Enquiry {
  final int id;
  final String? school;
  final List<dynamic> interactions;
  final List<dynamic> followUps;
  final String? assignedToCounsellorDetails;
  final String? assignedToTelecallerDetails;
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
    required this.school,
    required this.interactions,
    required this.followUps,
    required this.assignedToCounsellorDetails,
    required this.assignedToTelecallerDetails,
    required this.currentStatusName,
    required this.sourceName,
    required this.firstName,
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
      school: json['school'],
      interactions: json['interactions'] ?? [],
      followUps: json['follow_ups'] ?? [],
      assignedToCounsellorDetails: json['assigned_to_counsellor_details'],
      assignedToTelecallerDetails: json['assigned_to_telecaller_details'],
      currentStatusName: json['current_status_name'],
      sourceName: json['source_name'],
      firstName: json['first_name'],
      middleName: json['middle_name'],
      lastName: json['last_name'],
      dateOfBirth: json['date_of_birth'],
      phoneNumber: json['phone_number'],
      email: json['email'],
      address: json['address'],
      pincode: json['pincode'],
      referredBy: json['referred_by'] != null
          ? List<String>.from(json['referred_by'])
          : [],
      fatherPhoneNumber: json['father_phone_number'],
      motherPhoneNumber: json['mother_phone_number'],
      fatherOccupation: json['father_occupation'],
      enquiringForStandard: json['enquiring_for_standard'],
      enquiringForBoard: json['enquiring_for_board'],
      enquiringForExam: json['enquiring_for_exam'],
      leadTemperature: json['lead_temperature'],
      totalFeesDecided: json['total_fees_decided'],
      installmentsAgreed: json['installments_agreed'],
      isAdmissionConfirmed: json['is_admission_confirmed'] ?? false,
      referral: json['referral'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  /// ✅ Convert object to JSON (useful if you need to send back)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school': school,
      'interactions': interactions,
      'follow_ups': followUps,
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
