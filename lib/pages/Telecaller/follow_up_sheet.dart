import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../services/enquiry_service.dart';
import '../../models/enquiry_model.dart';
import '../miscellaneous/follow_up_page.dart'; // for FollowUp model

class AddFollowUpSheet extends StatefulWidget {
  final Enquiry enquiry;
  final FollowUp? existingFollowUp;

  const AddFollowUpSheet({
    super.key,
    required this.enquiry,
    this.existingFollowUp,
  });

  @override
  State<AddFollowUpSheet> createState() => _AddFollowUpSheetState();
}

class _AddFollowUpSheetState extends State<AddFollowUpSheet> {
  final _formKey = GlobalKey<FormState>();
  final EnquiryService _enquiryService = EnquiryService();
  Logger logger = Logger();
  bool _isLoading = false;

  bool _isCnr = false;
  String? _standard;
  String? _board;
  final Set<String> _selectedExams = {};
  bool? _admissionConfirmed;
  final _feedbackController = TextEditingController();

  late Future<List<dynamic>> _statusFuture;
  List<dynamic> _statuses = [];
  int? _selectedStatusId;
  bool _isStatusInitialized = false;

  DateTime? _nextFollowUpDate;

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

      // If editing, prefill after statuses loaded
      if (widget.existingFollowUp != null) {
        final f = widget.existingFollowUp!;
        _feedbackController.text = f.remarks;
        _isCnr = f.remarks.toLowerCase().contains('cnr');

        if (f.nextFollowUpDate != null) {
          try {
            _nextFollowUpDate = DateTime.parse(f.nextFollowUpDate!);
          } catch (_) {
            _nextFollowUpDate = null;
          }
        }

        if (f.statusAfterFollowUp != null) {
          // statusAfterFollowUp in FollowUp model is a name — try to map to id
          final matching = _statuses.firstWhere(
            (s) => (s['name'] as String).toLowerCase() ==
                f.statusAfterFollowUp!.toLowerCase(),
            orElse: () => null,
          );
          if (matching != null) {
            _selectedStatusId = matching['id'] as int?;
          }
        }
      }
    } catch (e) {
      logger.e('Failed to load statuses: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isStatusInitialized = true;
        });
      }
    }
  }

  Future<void> _pickNextFollowUpDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _nextFollowUpDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    final initialTime = _nextFollowUpDate != null
        ? TimeOfDay.fromDateTime(_nextFollowUpDate!)
        : const TimeOfDay(hour: 10, minute: 0);

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() => _nextFollowUpDate = combined);
  }

  Future<void> _submitForm() async {
    if (!_isCnr && !_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final Map<String, dynamic> payload;

    if (_isCnr) {
      final cnrStatus = _statuses.firstWhere(
        (status) => (status['name'] as String).toLowerCase() == 'cnr',
        orElse: () => null,
      );

      payload = {
        'enquiry': widget.enquiry.id,
        'remarks': 'CNR (Contact Not Received)',
        'status_after_follow_up': cnrStatus?['id'],
        'next_follow_up_date': null,
        'academic_details_discussed': 'N/A - CNR',
        'cnr': true,
      };
    } else {
      payload = {
        'enquiry': widget.enquiry.id,
        'remarks': _feedbackController.text.trim(),
        'status_after_follow_up': _selectedStatusId,
        'next_follow_up_date': _nextFollowUpDate?.toIso8601String(),
        'academic_details_discussed':
            "Standard: $_standard, Board: $_board, Exams: ${_selectedExams.join(', ')}, Admission: ${_admissionConfirmed == null ? 'N/A' : (_admissionConfirmed! ? 'Yes' : 'No')}",
        'cnr': false,
      };
    }

    try {
      if (widget.existingFollowUp == null) {
        await _enquiryService.addFollowUp(payload);
      } else {
        await _enquiryService.updateFollowUp(widget.existingFollowUp!.id, payload);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingFollowUp == null
                ? 'Follow-up saved successfully!'
                : 'Follow-up updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      logger.e('Failed to save follow-up: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save follow-up: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
            16.0,
            16.0,
            16.0,
            MediaQuery.of(context).viewInsets.bottom + 16.0,
          ),
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
                      widget.existingFollowUp == null ? 'Enquiry Follow-up' : 'Edit Follow-up',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoTile(
                          'Student Name',
                          '${widget.enquiry.firstName} ${widget.enquiry.lastName ?? ''}'.trim(),
                        ),
                        _buildInfoTile('Mobile No.', widget.enquiry.phoneNumber),
                        const SizedBox(height: 8),
                        _buildSectionTitle('Follow-up Details'),
                        _buildCnrToggle(),
                        const SizedBox(height: 10),
                        if (!_isCnr) ...[
                          _buildStatusDropdown(),
                          const SizedBox(height: 16),
                          _buildDateTimePicker(),
                          _buildTextField(_feedbackController, 'Feedback / Remarks'),
                          _buildSectionTitle('Academic & Admission Details (Enquiry)'),
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
                            _admissionConfirmed == null ? null : (_admissionConfirmed! ? 'Yes' : 'No'),
                            (val) => setState(() => _admissionConfirmed = (val == 'Yes')),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
                              : Text(widget.existingFollowUp == null ? 'Save Follow-up' : 'Update Follow-up'),
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

  Widget _buildCnrToggle() {
    return SwitchListTile(
      title: const Text('CNR (Contact Not Received)', style: TextStyle(fontWeight: FontWeight.w600)),
      value: _isCnr,
      onChanged: (bool value) => setState(() => _isCnr = value),
      secondary: Icon(Icons.phone_missed, color: _isCnr ? Theme.of(context).colorScheme.primary : Colors.grey),
      contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
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
      initialValue: _selectedStatusId,
      decoration: const InputDecoration(labelText: 'New Status', border: OutlineInputBorder()),
      items: _statuses.map((status) {
        return DropdownMenuItem<int>(
          value: status['id'] as int,
          child: Text(status['name'] as String),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedStatusId = value),
      validator: (value) => value == null ? 'Please select a status' : null,
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Next Follow-up Date & Time', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickNextFollowUpDateTime,
          child: Container(
            height: 55,
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline), borderRadius: BorderRadius.circular(4.0)),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _nextFollowUpDate == null ? 'Select date & time (Optional)' : DateFormat.yMMMd().add_jm().format(_nextFollowUpDate!),
                  style: TextStyle(color: _nextFollowUpDate == null ? Theme.of(context).textTheme.bodySmall?.color : null, fontSize: 16),
                ),
                Icon(Icons.calendar_today_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
      title: Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(top: 16.0, bottom: 8.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        maxLines: 3,
        validator: (value) => (value == null || value.isEmpty) ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildChoiceChipGroup(String title, List<String> options, String? groupValue, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: options.map((option) {
            final bool isSelected = groupValue == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha:0.03),
              onSelected: (selected) {
                if (selected) onChanged(option);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCheckboxGroup(String title, List<String> options, Set<String> selectedValues) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: options.map((option) {
            final bool isSelected = selectedValues.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha:0.03),
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
