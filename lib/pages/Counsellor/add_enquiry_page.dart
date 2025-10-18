import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/widgets/back_button.dart';
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

  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentStep = 0;

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
    _loadInitialData();
  }

  @override
  void dispose() {
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
    setState(() {
      _academicForms.removeAt(index);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonIos(),
        title: const Text('New Enquiry'),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
                child: Stepper(
                  type: StepperType.vertical,
                  currentStep: _currentStep,
                  onStepContinue: () {
                    if (_currentStep < 2) {
                      setState(() => _currentStep += 1);
                    } else {
                      _submitForm();
                    }
                  },
                  onStepCancel: () {
                    if (_currentStep > 0) {
                      setState(() => _currentStep -= 1);
                    }
                  },
                  onStepTapped: (step) => setState(() => _currentStep = step),
                  controlsBuilder: (context, details) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        children: <Widget>[
                          ElevatedButton(
                            onPressed: details.onStepContinue,
                            child: Text(
                              details.currentStep == 2 ? 'Submit' : 'Next',
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (details.currentStep > 0)
                            TextButton(
                              onPressed: details.onStepCancel,
                              child: const Text('Back'),
                            ),
                        ],
                      ),
                    );
                  },
                  steps: _buildSteps(),
                ),
              ),
            ),
    );
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Student & Parent Info'),
        content: _buildStep1(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Academic Details'),
        content: _buildStep2(),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Office & Financials'),
        content: _buildStep3(),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
    ];
  }

  Widget _buildStep1() {
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
                key: ValueKey(
                  index,
                ), // Important for stateful widgets in a list
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

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    List<Widget>? actions,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
        decoration: InputDecoration(labelText: label),
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
        decoration: InputDecoration(labelText: label),
        value: value,
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
        decoration: InputDecoration(labelText: label),
        value: value,
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
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: options.map((option) {
            return ChoiceChip(
              label: Text(option),
              selected: groupValue == option,
              onSelected: (selected) {
                if (selected) onChanged(option);
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
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: options
              .map(
                (option) => FilterChip(
                  label: Text(option),
                  selected: selectedValues.contains(option),
                  onSelected: (selected) => setState(
                    () => selected
                        ? selectedValues.add(option)
                        : selectedValues.remove(option),
                  ),
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

/// A dedicated stateful widget to manage the state of a single academic form.
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

    _validateForm(); // Initial check
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
    if (isValid != _isSaveEnabled) {
      setState(() {
        _isSaveEnabled = isValid;
      });
    }
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
        _buildTextField(_standardController, 'Standard (e.g., 10th)'),
        _buildTextField(_boardController, 'Board (e.g., CBSE)'),
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
        decoration: InputDecoration(labelText: label),
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
