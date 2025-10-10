import 'package:dreamvision/services/enquiry_service.dart'; // Make sure this path is correct
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class AddEnquiryPage extends StatefulWidget {
  const AddEnquiryPage({super.key});

  @override
  State<AddEnquiryPage> createState() => _AddEnquiryPageState();
}

class _AddEnquiryPageState extends State<AddEnquiryPage> {
  final _formKey = GlobalKey<FormState>();
  final Logger _logger = Logger();
  final EnquiryService _enquiryService = EnquiryService();

  // --- FORM STATE VARIABLES ---

  // Loading states
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Data for dropdowns fetched from API
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _statuses = [];
  List<Map<String, dynamic>> _schools = [];
  static const int _otherSchoolId = -1; // Special ID for "Other" option

  // A list to hold controllers for each dynamic academic form
  final List<Map<String, TextEditingController>> _academicForms = [];

  // Date Pickers, Selection Groups, and Dropdown IDs
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

  // Controllers for text fields
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
    _loadInitialData();
  }

  @override
  void dispose() {
    // Dispose all static controllers
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

    // Dispose all controllers in the dynamic list
    for (var form in _academicForms) {
      form.forEach((key, controller) => controller.dispose());
    }
    super.dispose();
  }

  /// Adds a new set of controllers for an academic performance record.
  void _addAcademicForm() {
    setState(() {
      _academicForms.add({
        'standard_level': TextEditingController(),
        'board': TextEditingController(),
        'percentage': TextEditingController(),
        'science_marks': TextEditingController(),
        'maths_marks': TextEditingController(),
        'english_marks': TextEditingController(),
      });
    });
  }

  /// Removes an academic performance record at a given index.
  void _removeAcademicForm(int index) {
    // Dispose controllers before removing to prevent memory leaks
    _academicForms[index].forEach((key, controller) => controller.dispose());
    setState(() {
      _academicForms.removeAt(index);
    });
  }

  /// Fetches all necessary data for the form's dropdowns.
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not load form data. $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop(); // Go back if data fails to load
      }
    }
  }

  /// Validates and submits all form data to the backend.
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

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

      final List<Map<String, dynamic>> academicDataList = _academicForms.map((
        form,
      ) {
        return {
          'standard_level': form['standard_level']!.text,
          'board': form['board']!.text,
          'percentage': double.tryParse(form['percentage']!.text),
          'science_marks': int.tryParse(form['science_marks']!.text),
          'maths_marks': int.tryParse(form['maths_marks']!.text),
          'english_marks': int.tryParse(form['english_marks']!.text),
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
        'school_name': schoolName,
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
        'academic_performances': academicDataList,
      };

      await _enquiryService.createEnquiry(enquiryData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enquiry submitted successfully!'),
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

  // --- UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // In your AddEnquiryPage build method
      appBar: AppBar(
        // 1. A 'Close' button to dismiss the page
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('New Enquiry'),
        // 2. Styling for a modern look
        centerTitle: true,
        elevation: 1,
        // 3. A 'Save' button to submit the form from the top
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitForm,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8), // Some padding
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            'Date',
                            _selectedDate,
                            () => _pickDate(context, isDob: false),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDateField(
                            'DOB',
                            _selectedDob,
                            () => _pickDate(context, isDob: true),
                          ),
                        ),
                      ],
                    ),
                    _buildSectionTitle('Student Information'),
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
                    _buildApiDropdownField(
                      'School',
                      _schools,
                      _selectedSchoolId,
                      (val) => setState(() => _selectedSchoolId = val),
                      includeOther: true,
                    ),
                    Visibility(
                      visible: _selectedSchoolId == _otherSchoolId,
                      child: _buildTextField(
                        _otherSchoolController,
                        'Enter School Name',
                      ),
                    ),
                    _buildSectionTitle('Parent Information'),
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
                    _buildSectionTitle('Course / Academic Details'),
                    _buildRadioGroup(
                      'Enquiring for Standard',
                      ['11th', '12th', '10th', '9th', '8th'],
                      _enquiringForStandard,
                      (val) => setState(() => _enquiringForStandard = val),
                    ),
                    _buildDropdownField(
                      'Board',
                      ['SSC', 'CBSE', 'ICSE'],
                      _enquiringForBoard,
                      (val) => setState(() => _enquiringForBoard = val),
                    ),
                    _buildCheckboxGroup('Exam', [
                      ' JEE (M+A) ',
                      ' NEET (UG)',
                      ' MHT-CET + JEE (M)',
                      'MHT-CET + NEET (UG) ',
                      'MHT-CET',
                      'Regular',
                      'Foundation',
                      'Regular + Foundation',
                    ], _selectedExams),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Academic Performance'),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                          onPressed: _addAcademicForm,
                        ),
                      ],
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _academicForms.length,
                      itemBuilder: (context, index) {
                        return _buildAcademicForm(index);
                      },
                    ),
                    _buildSectionTitle('Referral Information'),
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
                    _buildSectionTitle('Office Use / Financials'),
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
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text('Submit Enquiry'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // --- FORM HELPER WIDGETS ---

  Widget _buildAcademicForm(int index) {
    final formControllers = _academicForms[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Record #${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red.shade700,
                ),
                onPressed: () => _removeAcademicForm(index),
              ),
            ],
          ),
          const Divider(),
          _buildTextField(
            formControllers['standard_level']!,
            'Standard (e.g., 10th)',
          ),
          _buildTextField(formControllers['board']!, 'Board (e.g., CBSE)'),
          _buildTextField(
            formControllers['percentage']!,
            'Percentage / CGPA',
            keyboardType: TextInputType.number,
            isRequired: false,
          ),
          _buildTextField(
            formControllers['science_marks']!,
            'Science Marks',
            keyboardType: TextInputType.number,
            isRequired: false,
          ),
          _buildTextField(
            formControllers['maths_marks']!,
            'Maths Marks',
            keyboardType: TextInputType.number,
            isRequired: false,
          ),
          _buildTextField(
            formControllers['english_marks']!,
            'English Marks',
            keyboardType: TextInputType.number,
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          border: const OutlineInputBorder(),
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
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
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
          border: const OutlineInputBorder(),
        ),
        value: value,
        items: items.map((String item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
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
    List<DropdownMenuItem<int>> dropdownItems = items.map((item) {
      return DropdownMenuItem<int>(
        value: item['id'],
        child: Text(item['name']),
      );
    }).toList();

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
          border: const OutlineInputBorder(),
        ),
        value: value,
        items: dropdownItems,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildRadioGroup(
    String title,
    List<String> options,
    String? groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        // Use SingleChildScrollView to make the Row scrollable
        SingleChildScrollView(
          scrollDirection:
              Axis.horizontal, // Set scroll direction to horizontal
          child: Row(
            children: options.map((option) {
              // Each option is a Radio button and its Text label
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: option,
                    groupValue: groupValue,
                    onChanged: onChanged,
                  ),
                  GestureDetector(
                    onTap: () => onChanged(option),
                    child: Text(option),
                  ),
                  const SizedBox(width: 8), // Optional spacing between items
                ],
              );
            }).toList(),
          ),
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
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        Wrap(
          spacing: 8.0,
          children: options
              .map(
                (option) => FilterChip(
                  label: Text(option),
                  selected: selectedValues.contains(option),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedValues.add(option);
                      } else {
                        selectedValues.remove(option);
                      }
                    });
                  },
                ),
              )
              .toList(),
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
