// FILE: lib/features/enquiry/add_enquiry_page.dart

import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/enquiry_form_model.dart';
import '../../utils/global_error_handler.dart';
import '../../widgets/academic_form_widget.dart';
import '../../widgets/form_navigation_controls.dart';

import 'package:dreamvision/widgets/form_widgets.dart';
import 'package:dreamvision/widgets/section_card.dart';

import '../../widgets/school_search_field.dart';

class AddEnquiryPage extends StatefulWidget {
  final Enquiry? enquiry;
  const AddEnquiryPage({super.key, this.enquiry});

  @override
  State<AddEnquiryPage> createState() => _AddEnquiryPageState();
}

class _AddEnquiryPageState extends State<AddEnquiryPage> {
  final Logger _logger = Logger();
  final EnquiryService _enquiryService = EnquiryService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  // The state is now managed by our new model!
  late final EnquiryFormModel _formModel;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool get _isEditMode => widget.enquiry != null;

  // Dropdown data
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _statuses = [];
  List<Map<String, dynamic>> _schools = [];
  final List<String> _occupations = [
    'Defence',
    'Doctor',
    'Farmer',
    'Govt. Service',
    'Police',
    'Private Job',
    'Teacher',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Create the model
    _formModel = EnquiryFormModel();

    _loadInitialData().then((_) {
      if (_isEditMode && mounted) {
        // Prefill the model
        _formModel.prefill(widget.enquiry!, _schools);

        // Prefill SCHOOL SEARCH TEXT
        if (_formModel.selectedSchoolId != null) {
          final selected = _schools.firstWhere(
            (s) => s['id'] == _formModel.selectedSchoolId,
            orElse: () => {},
          );

          if (selected.isNotEmpty) {
            _formModel.schoolSearchController.text = selected['name'];
          } else if (_formModel.selectedSchoolId ==
              EnquiryFormModel.otherSchoolId) {
            _formModel.schoolSearchController.text =
                _formModel.otherSchoolController.text;
          }
        }

        // Prefill Source dropdown
        final src = _sources.firstWhere(
          (s) => s['name'] == widget.enquiry!.sourceName,
          orElse: () => {},
        );
        if (src.isNotEmpty) _formModel.sourceId = src['id'];

        // Prefill Status dropdown
        final st = _statuses.firstWhere(
          (s) => s['name'] == widget.enquiry!.currentStatusName,
          orElse: () => {},
        );
        if (st.isNotEmpty) _formModel.currentStatusId = st['id'];

        // Re-render to show prefilled data
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _formModel.dispose(); // Dispose the model
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _enquiryService.getEnquirySources(),
        _enquiryService.getEnquiryStatuses(),
        _enquiryService.getSchools(),
      ]);
      if (mounted) {
        setState(() {
          _sources = List<Map<String, dynamic>>.from(results[0]);
          _statuses = List<Map<String, dynamic>>.from(results[1]);
          _schools = List<Map<String, dynamic>>.from(results[2]);
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Failed to load initial data: $e');
      if (mounted) {
        GlobalErrorHandler.error('Could not load form data. $e');
        Navigator.of(context).pop();
      }
    }
  }

  void _addAcademicForm() {
    setState(() {
      _formModel.academicForms.add({
        'standard_level': TextEditingController(),
        'board': TextEditingController(),
        'percentage': TextEditingController(),
        'science_marks': TextEditingController(),
        'maths_marks': TextEditingController(),
        'english_marks': TextEditingController(),
        'isSaved': false,
      });
    });
  }

  void _removeAcademicForm(int index) {
    // Dispose controllers before removing
    _formModel.academicForms[index].forEach((key, controller) {
      if (controller is TextEditingController) controller.dispose();
    });
    setState(() => _formModel.academicForms.removeAt(index));
  }

  Future<void> _submitForm() async {
    // Validate all forms
    bool allValid = true;
    for (var formKey in _formKeys) {
      if (formKey.currentState != null && !formKey.currentState!.validate()) {
        allValid = false;
      }
    }

    if (!allValid || _isSubmitting) {
      if (!allValid) {
        // If invalid, jump to the first page with an error
        int firstInvalidPage = _formKeys.indexWhere(
          (key) => key.currentState != null && !key.currentState!.validate(),
        );
        if (firstInvalidPage != -1 && firstInvalidPage != _currentPage) {
          _pageController.animateToPage(
            firstInvalidPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.ease,
          );
        }
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get the data map from our model
      final enquiryData = _formModel.toApiMap();

      if (_isEditMode) {
        await _enquiryService.updateEnquiry(widget.enquiry!.id, enquiryData);
      } else {
        await _enquiryService.createEnquiry(enquiryData);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        GlobalErrorHandler.success(
          'Enquiry ${_isEditMode ? 'updated' : 'submitted'} successfully!',
        );
      }
    } catch (e) {
      _logger.e('Failed to submit enquiry: $e');
      if (mounted) {
        GlobalErrorHandler.error('Error submitting form: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _nextPage() {
    // Validate the *current* page before moving
    if (_formKeys[_currentPage].currentState!.validate()) {
      if (_currentPage < 2) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // This is the last page, so submit
        _submitForm();
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (_formModel.selectedDob) ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _formModel.selectedDob) {
      setState(() {
        _formModel.selectedDob = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: const BackButtonIos(),
        title: Text(
          _isEditMode
              ? 'Edit Enquiry'
              : 'New Enquiry (Step ${_currentPage + 1} of 3)',
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: PageView(
                    // physics: const NeverScrollableScrollPhysics(), // Uncomment to disable swiping
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _buildStepPage(_buildStep1, 0),
                      _buildStepPage(_buildStep2, 1),
                      _buildStepPage(_buildStep3, 2),
                    ],
                  ),
                ),
                FormNavigationControls(
                  currentPage: _currentPage,
                  isSubmitting: _isSubmitting,
                  isEditMode: _isEditMode,
                  onNext: _nextPage,
                  onBack: _previousPage,
                ),
              ],
            ),
    );
  }

  // Helper to wrap each step's content
  Widget _buildStepPage(Widget Function() buildContent, int pageIndex) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      // We wrap the *content* in the Form, not the whole page
      child: Form(key: _formKeys[pageIndex], child: buildContent()),
    );
  }

  // -----------------------------------------------------------------
  // UI Builder methods for each step
  // -----------------------------------------------------------------

  Widget _buildStep1() {
    return Column(
      children: [
        SectionCard(
          title: 'Personal Details',
          children: [
            CustomTextField(
              _formModel.firstNameController,
              'First Name',
              isRequired: true,
            ),
            CustomTextField(
              _formModel.middleNameController,
              'Middle Name',
              isRequired: false,
            ),
            CustomTextField(
              _formModel.lastNameController,
              'Last Name',
              isRequired: false,
            ),
            CustomDateField(
              label: 'Date of Birth',
              date: _formModel.selectedDob,
              onTap: () => _pickDate(context),
              isRequired: true,
            ),
            CustomTextField(
              _formModel.phoneController,
              'Student\'s Phone',
              keyboardType: TextInputType.phone,
              validatorType: "phone",
              isRequired: false,
            ),
            CustomTextField(
              _formModel.emailController,
              'Email',
              keyboardType: TextInputType.emailAddress,
              isRequired: false,
            ),
            CustomTextField(
              _formModel.addressController,
              'Address',
              maxLines: 3,
              isRequired: false,
            ),
            CustomTextField(
              _formModel.pincodeController,
              'Pincode',
              keyboardType: TextInputType.number,
              isRequired: false,
              validatorType: "pincode",
            ),
          ],
        ),
        SectionCard(
          title: 'Parent Information',
          children: [
            CustomTextField(
              _formModel.fatherPhoneController,
              'Father\'s Phone',
              keyboardType: TextInputType.phone,
              validatorType: "phone",
              isRequired: true,
            ),
            CustomTextField(
              _formModel.motherPhoneController,
              'Mother\'s Phone',
              keyboardType: TextInputType.phone,
              validatorType: "phone",
              isRequired: false,
            ),
            CustomDropdownField(
              label: 'Father\'s Occupation',
              items: _occupations,
              value: _formModel.fatherOccupation,
              onChanged: (val) =>
                  setState(() => _formModel.fatherOccupation = val),
              isRequired: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        SectionCard(
          title: 'Course Details',
          children: [
            CustomChoiceChipGroup(
              title: 'Enquiring for Standard',
              options: const ['8th', '9th', '10th', '11th', '12th'],
              groupValue: _formModel.enquiringForStandard,
              onChanged: (val) =>
                  setState(() => _formModel.enquiringForStandard = val),
              isRequired: true,
            ),
            const SizedBox(height: 16),
            CustomDropdownField(
              label: 'Board',
              items: const ['SSC', 'CBSE', 'ICSE'],
              value: _formModel.enquiringForBoard,
              onChanged: (val) =>
                  setState(() => _formModel.enquiringForBoard = val),
              isRequired: true,
            ),
            CustomFilterChipGroup(
              title: 'Exam',
              options: const [
                'JEE (M+A)',
                'NEET (UG)',
                'MHT-CET + JEE (M)',
                'MHT-CET + NEET (UG)',
                'MHT-CET',
                'Regular',
                'Foundation',
                'Regular + Foundation',
                'Other',
              ],
              selectedValues: _formModel.selectedExams,
              onChanged: (option, isSelected) {
                setState(() {
                  if (isSelected) {
                    _formModel.selectedExams.add(option);
                  } else {
                    _formModel.selectedExams.remove(option);
                  }
                });
              },
              isRequired: true,
            ),
            const SizedBox(height: 16),
            SearchableSchoolField(
              schools: _schools,
              value: _formModel.selectedSchoolId,
              controller: _formModel.schoolSearchController,
              onChanged: (id) {
                setState(() => _formModel.selectedSchoolId = id);
              },
            ),
          ],
        ),
        SectionCard(
          title: 'Academic Performance',
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addAcademicForm,
            ),
          ],
          children: [
            if (_formModel.academicForms.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('No academic records added.'),
                ),
              ),
            ...List.generate(
              _formModel.academicForms.length,
              (index) => AcademicFormWidget(
                key: ValueKey(index), // Use index as key
                formControllers: _formModel.academicForms[index],
                index: index,
                onRemove: () => _removeAcademicForm(index),
                onSave: () => setState(
                  () => _formModel.academicForms[index]['isSaved'] = true,
                ),
                onEdit: () => setState(
                  () => _formModel.academicForms[index]['isSaved'] = false,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        SectionCard(
          title: 'Referral Information',
          children: [
            CustomFilterChipGroup(
              title: 'Referred By',
              options: const [
                'Friends/Family',
                'Internet',
                'Hoarding',
                'Pamphlets',
                'Newspaper',
                'Call',
              ],
              selectedValues: _formModel.referredBy,
              onChanged: (option, isSelected) {
                setState(() {
                  if (isSelected) {
                    _formModel.referredBy.add(option);
                  } else {
                    _formModel.referredBy.remove(option);
                  }
                });
              },
              isRequired: false,
            ),
            CustomTextField(
              _formModel.referralController,
              'Optional Referral Code',
              isRequired: false,
            ),
          ],
        ),
        SectionCard(
          title: 'Office Use',
          children: [
            CustomApiDropdownField(
              label: 'Current Status',
              items: _statuses,
              isRequired: true,
              value: _formModel.currentStatusId,
              onChanged: (val) =>
                  setState(() => _formModel.currentStatusId = val),
            ),
            CustomDropdownField(
              label: 'Lead Temperature',
              isRequired: true,
              items: const ['Hot', 'Warm', 'Cold'],
              value: _formModel.leadTemperature,
              onChanged: (val) =>
                  setState(() => _formModel.leadTemperature = val),
            ),
            CustomTextField(
              _formModel.totalFeesController,
              'Total Fees Decided',
              keyboardType: TextInputType.number,
              isRequired: false,
            ),
            CustomTextField(
              _formModel.installmentsController,
              'Installments Agreed',
              keyboardType: TextInputType.number,
              isRequired: false,
            ),
          ],
        ),
      ],
    );
  }
}
