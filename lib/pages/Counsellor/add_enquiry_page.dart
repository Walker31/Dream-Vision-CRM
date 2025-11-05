import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class AddEnquiryPage extends StatefulWidget {
  final Enquiry? enquiry;

  const AddEnquiryPage({super.key, this.enquiry});

  @override
  State<AddEnquiryPage> createState() => _AddEnquiryPageState();
}

class _AddEnquiryPageState extends State<AddEnquiryPage> {
  final Logger _logger = Logger();
  final EnquiryService _enquiryService = EnquiryService();

  // --- PageView & Form State ---
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(), // Key for Step 1
    GlobalKey<FormState>(), // Key for Step 2
    GlobalKey<FormState>(), // Key for Step 3
  ];

  // --- Loading States ---
  bool _isLoading = true;
  bool _isSubmitting = false;

  bool get _isEditMode => widget.enquiry != null;

  // --- Data & Controllers (same as before) ---
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _statuses = [];
  List<Map<String, dynamic>> _schools = [];
  static const int _otherSchoolId = -1;
  final List<Map<String, dynamic>> _academicForms = [];
  DateTime? _selectedDate = DateTime.now();
  DateTime? _selectedDob;
  String? _enquiringForStandard;
  final Set<String> _selectedExams = {};
  final Set<String> _referredBy = {};
  String? _enquiringForBoard;
  String? _leadTemperature;
  int? _sourceId;
  int? _currentStatusId;
  int? _selectedSchoolId;
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _otherSchoolController = TextEditingController();
  final _fatherPhoneController = TextEditingController();
  final _motherPhoneController = TextEditingController();
  final _fatherOccupationController = TextEditingController();
  final _totalFeesController = TextEditingController();
  final _installmentsController = TextEditingController();
  final _referralController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 4. MODIFIED: Load data first, then pre-fill if in edit mode
    _loadInitialData().then((_) {
      if (_isEditMode && mounted) {
        _prefillData(widget.enquiry!);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _otherSchoolController.dispose();
    _fatherPhoneController.dispose();
    _motherPhoneController.dispose();
    _fatherOccupationController.dispose();
    _totalFeesController.dispose();
    _installmentsController.dispose();
    _referralController.dispose();
    for (var form in _academicForms) {
      form.forEach((key, controller) {
        if (controller is TextEditingController) controller.dispose();
      });
    }
    super.dispose();
  }

  // --- Data Loading ---
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
      // Prefill logic is now in initState, after this future completes
    } catch (e) {
      _logger.e('Failed to load initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not load form data. $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  // 5. NEW: Method to pre-fill all form data from an existing enquiry
  void _prefillData(Enquiry enquiry) {
    setState(() {
      // --- Step 1 Fields ---
      _firstNameController.text = enquiry.firstName;
      _middleNameController.text = enquiry.middleName ?? '';
      _lastNameController.text = enquiry.lastName ?? '';
      _phoneController.text = enquiry.phoneNumber;
      _emailController.text = enquiry.email ?? '';
      _addressController.text = enquiry.address ?? '';
      
      // --- ✅ BUG FIX HERE ---
      _pincodeController.text = enquiry.pincode?.toString() ?? '';
      // --- ✅ END BUG FIX ---

      _fatherPhoneController.text = enquiry.fatherPhoneNumber ?? '';
      _motherPhoneController.text = enquiry.motherPhoneNumber ?? '';
      _fatherOccupationController.text = enquiry.fatherOccupation ?? '';

      if (enquiry.dateOfBirth != null) {
        _selectedDob = DateTime.tryParse(enquiry.dateOfBirth!);
      }

      // --- Step 2 Fields ---
      _enquiringForStandard = enquiry.enquiringForStandard;
      _enquiringForBoard = enquiry.enquiringForBoard;

      // Handle School
      final school = _schools.firstWhere(
        (s) => s['name'] == enquiry.schoolName,
        orElse: () => {},
      );
      if (school.isNotEmpty) {
        _selectedSchoolId = school['id'];
      } else if (enquiry.schoolName != null && enquiry.schoolName!.isNotEmpty) {
        // It's an "Other" school
        _selectedSchoolId = _otherSchoolId;
        _otherSchoolController.text = enquiry.schoolName!;
      }

      // Handle Exams (assuming enquiringForExam is a comma-separated string)
      if (enquiry.enquiringForExam != null) {
        _selectedExams.addAll(
            enquiry.enquiringForExam!.split(', ').where((s) => s.isNotEmpty));
      }

      // Handle Academics (assuming academicPerformance is List<dynamic> of maps)
      if (enquiry.academicPerformance != null) {
        for (var acad in enquiry.academicPerformance!) {
          _academicForms.add({
            'standard_level':
                TextEditingController(text: acad['standard_level']?.toString() ?? ''),
            'board': TextEditingController(text: acad['board']?.toString() ?? ''),
            'percentage':
                TextEditingController(text: acad['percentage']?.toString() ?? ''),
            'science_marks': TextEditingController(
                text: acad['science_marks']?.toString() ?? ''),
            'maths_marks':
                TextEditingController(text: acad['maths_marks']?.toString() ?? ''),
            'english_marks': TextEditingController(
                text: acad['english_marks']?.toString() ?? ''),
            'isSaved': true, // Start in saved/summary mode
          });
        }
      }

      // --- Step 3 Fields ---
      _referralController.text = enquiry.referral ?? '';
      _leadTemperature = enquiry.leadTemperature;
      _totalFeesController.text = enquiry.totalFeesDecided ?? '';
      _installmentsController.text =
          enquiry.installmentsAgreed?.toString() ?? '';

      // Handle Referred By (assuming referredBy is List<String>)
      _referredBy.addAll(enquiry.referredBy.whereType<String>());
    
      // Handle API Dropdowns
      final source = _sources.firstWhere(
        (s) => s['name'] == enquiry.sourceName,
        orElse: () => {},
      );
      if (source.isNotEmpty) _sourceId = source['id'];

      final status = _statuses.firstWhere(
        (s) => s['name'] == enquiry.currentStatusName,
        orElse: () => {},
      );
      if (status.isNotEmpty) _currentStatusId = status['id'];
    });
  }

  // --- Academic Form Management (same as before) ---
  void _addAcademicForm() {
    setState(() {
      _academicForms.add({
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
    _academicForms[index].forEach((key, controller) {
      if (controller is TextEditingController) controller.dispose();
    });
    setState(() => _academicForms.removeAt(index));
  }

  // --- Form Submission ---
  Future<void> _submitForm() async {
    // Validate the *last* form key before submitting
    if (!_formKeys[_currentPage].currentState!.validate() || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? schoolName;
      if (_selectedSchoolId == _otherSchoolId) {
        schoolName = _otherSchoolController.text;
      } else if (_selectedSchoolId != null) {
        schoolName = _schools.firstWhere(
          (s) => s['id'] == _selectedSchoolId,
        )['name'];
      }

      final List<Map<String, dynamic>> academicDataList =
          _academicForms.map((
        form,
      ) {
        return {
          'standard_level':
              (form['standard_level'] as TextEditingController).text,
          'board': (form['board'] as TextEditingController).text,
          'percentage': double.tryParse(
            (form['percentage'] as TextEditingController).text,
          ),
          'science_marks': int.tryParse(
            (form['science_marks'] as TextEditingController).text,
          ),
          'maths_marks': int.tryParse(
            (form['maths_marks'] as TextEditingController).text,
          ),
          'english_marks': int.tryParse(
            (form['english_marks'] as TextEditingController).text,
          ),
        };
      }).toList();

      final enquiryData = {
        'first_name': _firstNameController.text,
        'middle_name': _middleNameController.text,
        'last_name': _lastNameController.text,
        'date_of_birth': _selectedDob?.toIso8601String().split('T').first,
        'phone_number': _phoneController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'pincode': _pincodeController.text,
        'school': schoolName, // Use corrected key
        'referred_by': _referredBy.toList(),
        'enquiring_for_standard': _enquiringForStandard,
        'enquiring_for_exam': _selectedExams.join(', '),
        'father_phone_number': _fatherPhoneController.text,
        'mother_phone_number': _motherPhoneController.text,
        'father_occupation': _fatherOccupationController.text,
        'enquiring_for_board': _enquiringForBoard,
        'lead_temperature': _leadTemperature,
        'total_fees_decided': _totalFeesController.text.isNotEmpty
            ? _totalFeesController.text
            : null,
        'installments_agreed': _installmentsController.text.isNotEmpty
            ? int.tryParse(_installmentsController.text)
            : null,
        'referral': _referralController.text,
        'source': _sourceId,
        'current_status': _currentStatusId,
        'academic_performance': academicDataList, // Use corrected key
      };

      // 6. MODIFIED: Call update or create based on edit mode
      if (_isEditMode) {
        await _enquiryService.updateEnquiry(widget.enquiry!.id, enquiryData);
      } else {
        await _enquiryService.createEnquiry(enquiryData);
      }

      if (mounted) {
        // 7. MODIFIED: Pop with 'true' to signal success
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Enquiry ${(_isEditMode ? 'updated' : 'submitted')} successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.e('Failed to submit enquiry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting form: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // --- Page Navigation Logic ---
  void _nextPage() {
    // Validate the current page's form before proceeding
    if (_formKeys[_currentPage].currentState!.validate()) {
      if (_currentPage < 2) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // If on the last page, submit the form
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonIos(), // Use your custom back button
        // 8. MODIFIED: AppBar title changes based on mode
        title: Text(_isEditMode
            ? 'Edit Enquiry'
            : 'New Enquiry (Step ${_currentPage + 1} of 3)'),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      // Wrap each step's content in its own Form widget
                      _buildStepPage(_buildStep1, 0),
                      _buildStepPage(_buildStep2, 1),
                      _buildStepPage(_buildStep3, 2),
                    ],
                  ),
                ),
                // --- Navigation Controls ---
                _buildNavigationControls(),
              ],
            ),
    );
  }

  // Helper to wrap step content in Padding and Form
  Widget _buildStepPage(Widget Function() buildContent, int pageIndex) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Form(key: _formKeys[pageIndex], child: buildContent()),
    );
  }

  // --- Build Methods for Each Step/Page ---
  Widget _buildStep1() {
    // Content is the same, just return the Column directly
    return Column(
      children: [
        _buildSectionCard(
          title: 'Personal Details',
          children: [
            _buildTextField(_firstNameController, 'First Name'),
            _buildTextField(
              _middleNameController,
              'Middle Name',
              isRequired: false,
            ),
            _buildTextField(
              _lastNameController,
              'Last Name',
              isRequired: false,
            ),
            _buildDateField(
              'Date of Birth',
              _selectedDob,
              () => _pickDate(context, isDob: true),
            ),
            _buildTextField(
              _phoneController,
              'Student\'s Phone',
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              _emailController,
              'Email',
              keyboardType: TextInputType.emailAddress,
              isRequired: false,
            ),
            _buildTextField(
              _addressController,
              'Address',
              maxLines: 3,
              isRequired: false,
            ),
            _buildTextField(
              _pincodeController,
              'Pincode',
              keyboardType: TextInputType.number,
              isRequired: false,
            ),
          ],
        ),
        _buildSectionCard(
          title: 'Parent Information',
          children: [
            _buildTextField(
              _fatherPhoneController,
              'Father\'s Phone',
              keyboardType: TextInputType.phone,
              isRequired: false,
            ),
            _buildTextField(
              _motherPhoneController,
              'Mother\'s Phone',
              keyboardType: TextInputType.phone,
              isRequired: false,
            ),
            _buildTextField(
              _fatherOccupationController,
              'Father\'s Occupation',
              isRequired: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Course Details',
          children: [
            _buildChoiceChipGroup(
              'Enquiring for Standard',
              ['11th', '12th', '10th', '9th', '8th'],
              _enquiringForStandard,
              (val) => setState(() => _enquiringForStandard = val),
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              'Board',
              ['SSC', 'CBSE', 'ICSE'],
              _enquiringForBoard,
              (val) => setState(() => _enquiringForBoard = val),
            ),
            _buildCheckboxGroup('Exam', [
              'JEE (M+A)',
              'NEET (UG)',
              'MHT-CET + JEE (M)',
              'MHT-CET + NEET (UG)',
              'MHT-CET',
              'Regular',
              'Foundation',
              'Regular + Foundation',
            ], _selectedExams),
            _buildApiDropdownField(
              'School',
              _schools,
              _selectedSchoolId,
              (val) => setState(() => _selectedSchoolId = val),
              includeOther: true,
            ),
            if (_selectedSchoolId == _otherSchoolId)
              _buildTextField(_otherSchoolController, 'Enter School Name'),
          ],
        ),
        _buildSectionCard(
          title: 'Academic Performance',
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addAcademicForm,
            ),
          ],
          children: [
            if (_academicForms.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('No academic records added.'),
                ),
              ),
            ...List.generate(
              _academicForms.length,
              (index) => _AcademicFormWidget(
                key: ValueKey(index),
                formControllers: _academicForms[index],
                index: index,
                onRemove: () => _removeAcademicForm(index),
                onSave: () =>
                    setState(() => _academicForms[index]['isSaved'] = true),
                onEdit: () =>
                    setState(() => _academicForms[index]['isSaved'] = false),
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
        _buildSectionCard(
          title: 'Referral Information',
          children: [
            _buildCheckboxGroup('Referred By', [
              'Friends/Family',
              'Internet',
              'Hoarding',
              'Pamphlets',
              'Newspaper',
              'Call',
            ], _referredBy),
            _buildTextField(
              _referralController,
              'Optional Referral Code',
              isRequired: false,
            ),
          ],
        ),
        _buildSectionCard(
          title: 'Office Use',
          children: [
            _buildApiDropdownField(
              'Source',
              _sources,
              _sourceId,
              (val) => setState(() => _sourceId = val),
            ),
            _buildApiDropdownField(
              'Current Status',
              _statuses,
              _currentStatusId,
              (val) => setState(() => _currentStatusId = val),
            ),
            _buildDropdownField(
              'Lead Temperature',
              ['Hot', 'Warm', 'Cold'],
              _leadTemperature,
              (val) => setState(() => _leadTemperature = val),
            ),
            _buildTextField(
              _totalFeesController,
              'Total Fees Decided',
              keyboardType: TextInputType.number,
              isRequired: false,
            ),
            _buildTextField(
              _installmentsController,
              'Installments Agreed',
              keyboardType: TextInputType.number,
              isRequired: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withAlpha(51), // 0.2 alpha
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Ensure spacing
          children: [
            // --- Back Button ---
            Opacity(
              // Use Opacity to hide but maintain layout space
              opacity: _currentPage > 0 ? 1.0 : 0.0,
              child: IgnorePointer(
                // Prevent taps when hidden
                ignoring: _currentPage == 0,
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  label: const Text('Back'),
                  onPressed: _isSubmitting ? null : _previousPage,
                ),
              ),
            ),

            // --- Page Indicator Dots ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) => _buildDotIndicator(index)),
            ),

            // --- Next/Submit Button ---
            ElevatedButton.icon(
              icon: _isSubmitting
                  ? Container(
                      width: 18,
                      height: 18,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              // 9. MODIFIED: Button label changes based on mode
              label: Text(
                _isSubmitting
                    ? 'Saving...'
                    : (_currentPage == 2
                        ? (_isEditMode ? 'Update' : 'Submit')
                        : 'Next'),
              ),
              onPressed: _isSubmitting ? null : _nextPage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDotIndicator(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: isActive ? 12.0 : 8.0,
      height: isActive ? 12.0 : 8.0,
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    List<Widget>? actions,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20), // Added more bottom margin
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (actions != null) Row(children: actions),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isRequired = true,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.withAlpha(26), // 0.1 alpha
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today),
            filled: true,
            fillColor: Colors.grey.withAlpha(26), // 0.1 alpha
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          child: Text(
            date != null ? DateFormat.yMd().format(date) : 'Select a date',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.withAlpha(26), // 0.1 alpha
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        initialValue: value, // Use 'value' instead of 'initialValue' for clarity
        items: items
            .map(
              (String item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildApiDropdownField(
    String label,
    List<Map<String, dynamic>> items,
    int? value,
    ValueChanged<int?> onChanged, {
    bool includeOther = false,
  }) {
    List<DropdownMenuItem<int>> dropdownItems = items
        .map(
          (item) => DropdownMenuItem<int>(
            value: item['id'],
            child: Text(item['name']),
          ),
        )
        .toList();
    if (includeOther) {
      dropdownItems.add(
        const DropdownMenuItem<int>(
          value: _otherSchoolId,
          child: Text('Other...'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<int>(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.withAlpha(26), // 0.1 alpha
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        initialValue: value, // Use 'value' instead of 'initialValue'
        items: dropdownItems,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildChoiceChipGroup(
    String title,
    List<String> options,
    String? groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        Wrap(
          spacing: 8.0,
          children: options.map((option) {
            final bool isSelected = groupValue == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              // Hide the default checkmark
              showCheckmark: false,
              // Set a custom color for the selected chip
              selectedColor: Theme.of(context).primaryColor,
              // Change the text style for better contrast when selected
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              // Optional: A subtle background for unselected chips
              backgroundColor: Colors.grey.withAlpha(26), // 0.1 alpha
              onSelected: (selected) {
                if (selected) {
                  onChanged(option);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCheckboxGroup(
    String title,
    List<String> options,
    Set<String> selectedValues,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: options.map((option) {
            final bool isSelected = selectedValues.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey.withAlpha(26), // 0.1 alpha
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedValues.add(option);
                  } else {
                    selectedValues.remove(option);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isDob}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isDob ? _selectedDob : _selectedDate) ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isDob) {
          _selectedDob = picked;
        } else {
          _selectedDate = picked;
        }
      });
    }
  }
}

// --- Academic Form Widget (Same as before) ---
class _AcademicFormWidget extends StatefulWidget {
  final Map<String, dynamic> formControllers;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onSave;
  final VoidCallback onEdit;
  const _AcademicFormWidget({
    super.key,
    required this.formControllers,
    required this.index,
    required this.onRemove,
    required this.onSave,
    required this.onEdit,
  });
  @override
  State<_AcademicFormWidget> createState() => _AcademicFormWidgetState();
}

class _AcademicFormWidgetState extends State<_AcademicFormWidget> {
  bool _isSaveEnabled = false;
  late final TextEditingController _standardController;
  late final TextEditingController _boardController;
  @override
  void initState() {
    super.initState();
    _standardController =
        widget.formControllers['standard_level'] as TextEditingController;
    _boardController = widget.formControllers['board'] as TextEditingController;
    _standardController.addListener(_validateForm);
    _boardController.addListener(_validateForm);
    _validateForm();
  }

  @override
  void dispose() {
    _standardController.removeListener(_validateForm);
    _boardController.removeListener(_validateForm);
    super.dispose();
  }

  void _validateForm() {
    final bool isValid =
        _standardController.text.isNotEmpty && _boardController.text.isNotEmpty;
    if (isValid != _isSaveEnabled) setState(() => _isSaveEnabled = isValid);
  }

  @override
  Widget build(BuildContext context) {
    final bool isSaved = widget.formControllers['isSaved'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: isSaved ? _buildSummary() : _buildEditForm(),
    );
  }

  Widget _buildSummary() {
    final percentage =
        (widget.formControllers['percentage'] as TextEditingController).text;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${_standardController.text} (${_boardController.text})',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Percentage/CGPA: ${percentage.isNotEmpty ? percentage : "N/A"}',
      ),
      trailing: TextButton(onPressed: widget.onEdit, child: const Text('Edit')),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Record #${widget.index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: Colors.red.shade700,
              ),
              onPressed: widget.onRemove,
            ),
          ],
        ),
        const Divider(),
        _buildTextField(
          _standardController,
          'Standard (e.g., 10th)',
          isRequired: true,
        ), // Make required fields clear
        _buildTextField(
          _boardController,
          'Board (e.g., CBSE)',
          isRequired: true,
        ),
        _buildTextField(
          widget.formControllers['percentage'] as TextEditingController,
          'Percentage / CGPA',
          keyboardType: TextInputType.number,
          isRequired: false,
        ),
        _buildTextField(
          widget.formControllers['science_marks'] as TextEditingController,
          'Science Marks',
          keyboardType: TextInputType.number,
          isRequired: false,
        ),
        _buildTextField(
          widget.formControllers['maths_marks'] as TextEditingController,
          'Maths Marks',
          keyboardType: TextInputType.number,
          isRequired: false,
        ),
        _buildTextField(
          widget.formControllers['english_marks'] as TextEditingController,
          'English Marks',
          keyboardType: TextInputType.number,
          isRequired: false,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _isSaveEnabled ? widget.onSave : null,
            child: const Text('Save Record'),
          ),
        ),
      ],
    );
  }

  // Local buildTextField - required for _AcademicFormWidget
  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isRequired = true,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.withAlpha(26), // Consistent fill
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }
}