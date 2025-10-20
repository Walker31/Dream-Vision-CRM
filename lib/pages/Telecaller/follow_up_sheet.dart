import 'package:dreamvision/services/enquiry_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/web.dart';

import '../../models/enquiry_model.dart';

class AddFollowUpSheet extends StatefulWidget {
  final Enquiry enquiry;

  const AddFollowUpSheet({super.key, required this.enquiry});

  @override
  State<AddFollowUpSheet> createState() => _AddFollowUpSheetState();
}

class _AddFollowUpSheetState extends State<AddFollowUpSheet> {
  final _formKey = GlobalKey<FormState>();
  final EnquiryService _enquiryService = EnquiryService();
  Logger logger = Logger();
  bool _isLoading = false;

  String? _standard;
  String? _board;
  final Set<String> _selectedExams = {};
  bool? _admissionConfirmed;

  final _feedbackController = TextEditingController();

  late Future<List<dynamic>> _statusFuture;
  List<dynamic> _statuses = [];
  int? _selectedStatusId;
  bool _isStatusInitialized = false;

  @override
  void initState() {
    super.initState();
    _standard = widget.enquiry.enquiringForStandard;
    _board = widget.enquiry.enquiringForBoard;
    _admissionConfirmed = widget.enquiry.isAdmissionConfirmed;
    _initializeStatus();
  }

  Future<void> _initializeStatus() async {
    try {
      _statusFuture = _enquiryService.getEnquiryStatuses();
      _statuses = await _statusFuture;

      final currentStatusName = widget.enquiry.currentStatusName;
      if (currentStatusName != null) {
        final matchingStatus = _statuses.firstWhere(
          (status) =>
              (status['name'] as String).toLowerCase() ==
              currentStatusName.toLowerCase(),
          orElse: () => null,
        );
        if (matchingStatus != null) {
          _selectedStatusId = matchingStatus['id'] as int?;
        } else {
          logger.w(
              "Current status name '$currentStatusName' not found in fetched statuses.");
        }
      }
    } catch (e) {
      logger.e("Failed to initialize statuses: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isStatusInitialized = true;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && !_isLoading) {
      setState(() => _isLoading = true);

      final followUpPayload = {
        'enquiry': widget.enquiry.id,
        'remarks': _feedbackController.text.trim(),
        'status_after_follow_up': _selectedStatusId,
        'next_follow_up_date':
            _nextFollowUpDate?.toIso8601String().split('T')[0],
        'academic_details_discussed':
            "Standard: $_standard, Board: $_board, Exams: ${_selectedExams.join(', ')}, Admission: ${_admissionConfirmed == null ? 'N/A' : (_admissionConfirmed! ? 'Yes' : 'No')}",
      };

      try {
        await _enquiryService.addFollowUp(followUpPayload);
        logger.d('Follow-up Submitted: $followUpPayload');

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Follow-up saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        logger.e("Failed to save follow-up: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to save follow-up: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  DateTime? _nextFollowUpDate;

  Future<void> _pickNextFollowUpDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _nextFollowUpDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && pickedDate != _nextFollowUpDate) {
      setState(() {
        _nextFollowUpDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16.0, 16.0, 16.0, MediaQuery.of(context).viewInsets.bottom + 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enquiry Follow-up',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoTile(
                          'Student Name',
                          '${widget.enquiry.firstName} ${widget.enquiry.lastName ?? ''}'
                              .trim(),
                        ),
                        _buildInfoTile(
                          'Mobile No.',
                          widget.enquiry.phoneNumber,
                        ),
                        _buildSectionTitle('Follow-up Details'),
                        _buildStatusDropdown(),
                        const SizedBox(height: 16),
                        _buildDatePicker(),
                        _buildTextField(
                          _feedbackController,
                          'Feedback / Remarks',
                        ),
                        _buildSectionTitle(
                            'Academic & Admission Details (Enquiry)'),
                        _buildChoiceChipGroup(
                          'Standard',
                          ['12th', '11th', '10th', '9th', '8th'],
                          _standard,
                          (val) => setState(() => _standard = val),
                        ),
                        const SizedBox(height: 8),
                        _buildChoiceChipGroup(
                          'Board',
                          ['SSC', 'ICSE', 'CBSE'],
                          _board,
                          (val) => setState(() => _board = val),
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
                        _buildChoiceChipGroup(
                          'Admission Confirmed',
                          ['Yes', 'No'],
                          _admissionConfirmed == null
                              ? null
                              : (_admissionConfirmed! ? 'Yes' : 'No'),
                          (val) => setState(
                            () => _admissionConfirmed = (val == 'Yes'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                )
                              : const Text('Save Follow-up'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    if (!_isStatusInitialized) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_statuses.isEmpty) {
      return const Text('Could not load statuses. Please try again later.');
    }

    return DropdownButtonFormField<int>(
      value: _selectedStatusId,
      decoration: const InputDecoration(
        labelText: 'New Status',
        border: OutlineInputBorder(),
      ),
      items: _statuses.map((status) {
        return DropdownMenuItem<int>(
          value: status['id'] as int,
          child: Text(status['name'] as String),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedStatusId = value;
        });
      },
      validator: (value) => value == null ? 'Please select a status' : null,
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next Follow-up Date',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickNextFollowUpDate,
          child: Container(
            height: 55,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _nextFollowUpDate == null
                      ? 'Select a date (Optional)'
                      : DateFormat.yMMMd().format(_nextFollowUpDate!),
                  style: TextStyle(
                    color: _nextFollowUpDate == null ? Colors.grey[600] : null,
                    fontSize: 16,
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.grey)),
      subtitle: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        maxLines: 3,
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Please enter $label' : null,
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
          runSpacing: 4.0,
          children: options.map((option) {
            final bool isSelected = groupValue == option;
            return ChoiceChip(
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
              backgroundColor: Colors.grey.withAlpha(25),
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
              backgroundColor: Colors.grey.withAlpha(25),
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
}