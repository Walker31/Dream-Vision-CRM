// FILE: lib/features/enquiry/widgets/academic_form_widget.dart

import 'package:dreamvision/widgets/form_widgets.dart';
import 'package:flutter/material.dart';

// This widget was already well-contained, just moving it to its own file.
// I've updated it to use the new CustomTextField.
class AcademicFormWidget extends StatefulWidget {
  final Map<String, dynamic> formControllers;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onSave;
  final VoidCallback onEdit;
  const AcademicFormWidget({
    super.key,
    required this.formControllers,
    required this.index,
    required this.onRemove,
    required this.onSave,
    required this.onEdit,
  });
  @override
  State<AcademicFormWidget> createState() => _AcademicFormWidgetState();
}

class _AcademicFormWidgetState extends State<AcademicFormWidget> {
  bool _isSaveEnabled = false;
  late final TextEditingController _standardController;
  late final TextEditingController _boardController;

  @override
  void initState() {
    super.initState();
    _standardController =
        widget.formControllers['standard_level'] as TextEditingController;
    _boardController =
        widget.formControllers['board'] as TextEditingController;
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
    final bool isValid = _standardController.text.isNotEmpty &&
        _boardController.text.isNotEmpty;
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
        CustomTextField(
          _standardController,
          'Standard (e.g., 10th)',
          isRequired: true,
        ),
        CustomTextField(
          _boardController,
          'Board (e.g., CBSE)',
          isRequired: true,
        ),
        CustomTextField(
          widget.formControllers['percentage'] as TextEditingController,
          'Percentage / CGPA',
          keyboardType: TextInputType.number,
          isRequired: false,
        ),
        CustomTextField(
          widget.formControllers['science_marks'] as TextEditingController,
          'Science Marks',
          keyboardType: TextInputType.number,
          isRequired: false,
        ),
        CustomTextField(
          widget.formControllers['maths_marks'] as TextEditingController,
          'Maths Marks',
          keyboardType: TextInputType.number,
          isRequired: false,
        ),
        CustomTextField(
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
}