// FILE: lib/features/enquiry/models/enquiry_form_model.dart

import 'package:dreamvision/models/enquiry_model.dart';
import 'package:flutter/material.dart';

class EnquiryFormModel {
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final pincodeController = TextEditingController();
  DateTime? selectedDob;

  final fatherPhoneController = TextEditingController();
  final motherPhoneController = TextEditingController();

  // Dropdown-only occupation
  String? fatherOccupation;

  String? enquiringForStandard;
  String? enquiringForBoard;
  final Set<int> selectedExamIds = {};

  int? selectedSchoolId;
  final otherSchoolController = TextEditingController();
  static const int otherSchoolId = -1;

  final List<Map<String, dynamic>> academicForms = [];

  final Set<String> referredBy = {};
  final referralController = TextEditingController();

  int? sourceId;
  int? currentStatusId;
  String? leadTemperature;

  final totalFeesController = TextEditingController();
  final installmentsController = TextEditingController();

  final TextEditingController schoolSearchController = TextEditingController();
  
  void prefill(Enquiry enquiry, List<Map<String, dynamic>> schools) {
    firstNameController.text = enquiry.firstName;
    middleNameController.text = enquiry.middleName ?? '';
    lastNameController.text = enquiry.lastName ?? '';
    phoneController.text = enquiry.phoneNumber ?? '';
    emailController.text = enquiry.email ?? '';
    addressController.text = enquiry.address ?? '';
    pincodeController.text = enquiry.pincode?.toString() ?? '';

    fatherPhoneController.text = enquiry.fatherPhoneNumber ?? '';
    motherPhoneController.text = enquiry.motherPhoneNumber ?? '';

    // Dropdown value
    fatherOccupation = enquiry.fatherOccupation;

    if (enquiry.dateOfBirth != null) {
      selectedDob = DateTime.tryParse(enquiry.dateOfBirth!);
    }

    enquiringForStandard = enquiry.enquiringForStandard;
    enquiringForBoard = enquiry.enquiringForBoard;

    // School selection
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

    // Exams - extract IDs from the exams list returned by API
    if (enquiry.exams.isNotEmpty) {
      selectedExamIds.addAll(
        enquiry.exams
            .map((exam) => exam['id'] as int)
            .where((id) => id > 0),
      );
    }

    // Academic performance
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
    installmentsController.text =
        enquiry.installmentsAgreed?.toString() ?? '';

    referredBy.addAll(enquiry.referredBy.whereType<String>());
  }


  Map<String, dynamic> toApiMap() {
    return {
      'first_name': firstNameController.text,
      'middle_name': middleNameController.text,
      'last_name': lastNameController.text,
      'date_of_birth': selectedDob?.toIso8601String().split('T').first,
      'phone_number': phoneController.text,
      'email': emailController.text.isNotEmpty ? emailController.text : null,
      'address': addressController.text,
      'pincode': pincodeController.text.isNotEmpty
          ? int.tryParse(pincodeController.text)
          : null,

      // School - if "Add School" was selected (otherSchoolId), send the text for backend auto-creation
      'school': (selectedSchoolId == otherSchoolId) ? null : selectedSchoolId,
      'school_name_text': (selectedSchoolId == otherSchoolId) ? otherSchoolController.text.trim() : '',

      // Referral + Course
      'referred_by': referredBy.toList(),
      'enquiring_for_standard': enquiringForStandard,
      'exam_ids': selectedExamIds.toList(),
      'enquiring_for_board': enquiringForBoard,

      // Parent details
      'father_phone_number': fatherPhoneController.text,
      'mother_phone_number': motherPhoneController.text,
      'father_occupation': fatherOccupation, // <--- FIXED

      // Office use
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

      // Academic Forms
      'academic_performances': academicForms.map<Map<String, dynamic>>((form) {
        return {
          'standard_level':
              (form['standard_level'] as TextEditingController).text,
          'board': (form['board'] as TextEditingController).text,
          'percentage':
              double.tryParse((form['percentage'] as TextEditingController).text),
          'science_marks': int.tryParse(
              (form['science_marks'] as TextEditingController).text),
          'maths_marks': int.tryParse(
              (form['maths_marks'] as TextEditingController).text),
          'english_marks': int.tryParse(
              (form['english_marks'] as TextEditingController).text),
        };
      }).toList(),
    };
  }

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
