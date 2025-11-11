// FILE: lib/features/enquiry/models/enquiry_form_model.dart

import 'package:dreamvision/models/enquiry_model.dart';
import 'package:flutter/material.dart';

class EnquiryFormModel {
  // Page 1: Personal
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final pincodeController = TextEditingController();
  DateTime? selectedDob;

  // Page 1: Parent
  final fatherPhoneController = TextEditingController();
  final motherPhoneController = TextEditingController();
  final fatherOccupationController = TextEditingController();

  // Page 2: Course
  String? enquiringForStandard;
  String? enquiringForBoard;
  final Set<String> selectedExams = {};
  int? selectedSchoolId;
  final otherSchoolController = TextEditingController();
  static const int otherSchoolId = -1; // Use this for "Other"

  // Page 2: Academics
  final List<Map<String, dynamic>> academicForms = [];

  // Page 3: Referral
  final Set<String> referredBy = {};
  final referralController = TextEditingController();

  // Page 3: Office
  int? sourceId;
  int? currentStatusId;
  String? leadTemperature;
  final totalFeesController = TextEditingController();
  final installmentsController = TextEditingController();

  /// Populates all controllers and fields from an existing Enquiry model.
  void prefill(Enquiry enquiry, List<Map<String, dynamic>> schools) {
    firstNameController.text = enquiry.firstName;
    middleNameController.text = enquiry.middleName ?? '';
    lastNameController.text = enquiry.lastName ?? '';
    phoneController.text = enquiry.phoneNumber;
    emailController.text = enquiry.email ?? '';
    addressController.text = enquiry.address ?? '';
    pincodeController.text = enquiry.pincode?.toString() ?? '';
    fatherPhoneController.text = enquiry.fatherPhoneNumber ?? '';
    motherPhoneController.text = enquiry.motherPhoneNumber ?? '';
    fatherOccupationController.text = enquiry.fatherOccupation ?? '';

    if (enquiry.dateOfBirth != null) {
      selectedDob = DateTime.tryParse(enquiry.dateOfBirth!);
    }

    enquiringForStandard = enquiry.enquiringForStandard;
    enquiringForBoard = enquiry.enquiringForBoard;

    final matchingSchool = schools.firstWhere(
      (s) => s['name'] == enquiry.schoolName,
      orElse: () => {},
    );

    if (matchingSchool.isNotEmpty) {
      selectedSchoolId = matchingSchool['id'];
    } else if ((enquiry.schoolName ?? '').isNotEmpty) {
      selectedSchoolId = otherSchoolId;
      otherSchoolController.text = enquiry.schoolName!;
    }

    if (enquiry.enquiringForExam != null) {
      selectedExams.addAll(
        enquiry.enquiringForExam!
            .split(RegExp(r'[,\s]+'))
            .where((e) => e.isNotEmpty),
      );
    }

    if (enquiry.academicPerformance != null) {
      for (var ac in enquiry.academicPerformance!) {
        academicForms.add({
          'standard_level':
              TextEditingController(text: ac['standard_level'] ?? ''),
          'board': TextEditingController(text: ac['board'] ?? ''),
          'percentage':
              TextEditingController(text: ac['percentage']?.toString() ?? ''),
          'science_marks':
              TextEditingController(text: ac['science_marks']?.toString() ?? ''),
          'maths_marks':
              TextEditingController(text: ac['maths_marks']?.toString() ?? ''),
          'english_marks':
              TextEditingController(text: ac['english_marks']?.toString() ?? ''),
          'isSaved': true,
        });
      }
    }

    referralController.text = enquiry.referral ?? '';
    leadTemperature = enquiry.leadTemperature;
    totalFeesController.text = enquiry.totalFeesDecided ?? '';
    installmentsController.text = enquiry.installmentsAgreed?.toString() ?? '';
    referredBy.addAll(enquiry.referredBy.whereType<String>());
  }

  /// Converts all form data into the Map required by the API.
  Map<String, dynamic> toApiMap() {
    // --- THIS IS THE FIX ---
    // We send empty strings "" instead of null for text fields.
    // The .text property of a controller is never null.
    final data = {
      'first_name': firstNameController.text,
      'middle_name': middleNameController.text,
      'last_name': lastNameController.text,
      'date_of_birth': selectedDob?.toIso8601String().split('T').first,
      'phone_number': phoneController.text,
      'email': emailController.text.isNotEmpty ? emailController.text : null,
      'address': addressController.text, // Fix: Send "" not null
      'pincode': pincodeController.text.isNotEmpty
          ? int.tryParse(pincodeController.text)
          : null,
      'school': (selectedSchoolId == otherSchoolId) ? null : selectedSchoolId,
      // Note: You may need a 'school_name_other' field if school is null
      'referred_by': referredBy.toList(),
      'enquiring_for_standard': enquiringForStandard,
      'enquiring_for_exam': selectedExams.join(', '),
      'enquiring_for_board': enquiringForBoard,
      'father_phone_number':
          fatherPhoneController.text, // Fix: Send "" not null
      'mother_phone_number':
          motherPhoneController.text, // Fix: Send "" not null
      'father_occupation':
          fatherOccupationController.text, // Fix: Send "" not null
      'lead_temperature': leadTemperature,
      'total_fees_decided': totalFeesController.text.isNotEmpty
          ? totalFeesController.text
          : null,
      'installments_agreed': installmentsController.text.isNotEmpty
          ? int.tryParse(installmentsController.text)
          : null,
      'referral':
          referralController.text.isNotEmpty ? referralController.text : null,
      'source': sourceId,
      'current_status': currentStatusId,
      'academic_performance': academicForms.map<Map<String, dynamic>>((form) {
        return {
          'standard_level':
              (form['standard_level'] as TextEditingController).text,
          'board': (form['board'] as TextEditingController).text,
          'percentage': double.tryParse(
              (form['percentage'] as TextEditingController).text),
          'science_marks': int.tryParse(
              (form['science_marks'] as TextEditingController).text),
          'maths_marks':
              int.tryParse((form['maths_marks'] as TextEditingController).text),
          'english_marks': int.tryParse(
              (form['english_marks'] as TextEditingController).text),
        };
      }).toList(),
    };

    return data;
  }

  /// Disposes all TextEditingControllers to prevent memory leaks.
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    pincodeController.dispose();
    otherSchoolController.dispose();
    fatherPhoneController.dispose();
    motherPhoneController.dispose();
    fatherOccupationController.dispose();
    totalFeesController.dispose();
    installmentsController.dispose();
    referralController.dispose();

    for (var form in academicForms) {
      form.forEach((key, controller) {
        if (controller is TextEditingController) controller.dispose();
      });
    }
  }
}