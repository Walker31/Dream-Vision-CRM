
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/web.dart';

class AddFollowUpSheet extends StatefulWidget {
  const AddFollowUpSheet({super.key});

  @override
  State<AddFollowUpSheet> createState() => _AddFollowUpSheetState();
}

class _AddFollowUpSheetState extends State<AddFollowUpSheet> {
  final _formKey = GlobalKey<FormState>();
  Logger logger = Logger();

  // Form state variables
  String? _standard;
  String? _board;
  final Set<String> _selectedExams = {};
  bool? _admissionConfirmed;
  final _feedbackController = TextEditingController();

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final followUpData = {
        'student_name': 'Riya Gupta', // This would be passed into the widget
        'standard': _standard,
        'board': _board,
        'exams': _selectedExams.toList(),
        'admission_confirmed': _admissionConfirmed,
        'feedback': _feedbackController.text,
        'date': DateFormat.yMd().format(DateTime.now()),
      };

      // TODO: Send data to the backend
      logger.d('Follow-up Submitted: $followUpData');

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow-up saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
              // Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoTile('Student Name', 'Riya Gupta'),
                      _buildInfoTile('Mobile No.', '9876543210'),
                      _buildSectionTitle('Academic Details'),
                      _buildRadioGroup(
                        'Standard',
                        ['11th', '12th'],
                        _standard,
                        (val) => setState(() => _standard = val),
                      ),
                      _buildRadioGroup(
                        'Board',
                        ['SSC', 'CBSE'],
                        _board,
                        (val) => setState(() => _board = val),
                      ),
                      _buildCheckboxGroup('Exam', [
                        'JEE',
                        'NEET',
                        'MHT-CET',
                      ], _selectedExams),
                      _buildSectionTitle('Admission Status'),
                      _buildRadioGroup(
                        'Admission Confirmed',
                        ['Yes', 'No'],
                        _admissionConfirmed == null
                            ? null
                            : (_admissionConfirmed! ? 'Yes' : 'No'),
                        (val) => setState(
                          () => _admissionConfirmed = (val == 'Yes'),
                        ),
                      ),
                      _buildTextField(
                        _feedbackController,
                        'Feedback / Remarks',
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save Follow-up'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FORM HELPER WIDGETS ---

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

  Widget _buildRadioGroup(
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
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        Row(
          children: options
              .map(
                (option) => Expanded(
                  child: RadioListTile<String>(
                    title: Text(option),
                    value: option,
                    groupValue: groupValue,
                    onChanged: onChanged,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              )
              .toList(),
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
          style: const TextStyle(fontSize: 14, color: Colors.black54),
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
}
