// FILE: lib/widgets/form_widgets.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Helper to build a label with a red asterisk if the field is required
Widget _buildLabel(String label, bool isRequired) {
  return Text.rich(
    TextSpan(
      text: label,
      children: [
        if (isRequired)
          const TextSpan(
            text: ' *',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    ),
  );
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isRequired;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? validatorType;

  const CustomTextField(
    this.controller,
    this.label, {
    super.key,
    this.isRequired = true,
    this.maxLines = 1,
    this.keyboardType,
    this.validatorType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: validatorType == "phone"
            ? 10
            : validatorType == "pincode"
                ? 6
                : null,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          label: _buildLabel(label, isRequired), // Used label instead of labelText
          filled: true,
          fillColor: Colors.grey.withAlpha(26),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        buildCounter: (
          BuildContext context, {
          required int currentLength,
          required bool isFocused,
          required int? maxLength,
        }) {
          return null;
        },
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }

          if (value == null || value.isEmpty) return null;
          final digits = value.replaceAll(RegExp(r'\D'), '');
          if (validatorType == "phone") {
            if (digits.length != 10) {
              return 'Please enter a valid mobile number.';
            }
          }

          if (validatorType == "pincode") {
            if (digits.length != 6) {
              return 'Please enter a valid pincode.';
            }
          }

          return null;
        },
      ),
    );
  }
}

class CustomDateField extends FormField<DateTime> {
  CustomDateField({
    super.key,
    required String label,
    super.initialValue,
    required VoidCallback onTap,
    bool isRequired = false,
    super.onSaved,
  }) : super(
    validator: isRequired
        ? (value) => value == null ? 'Please select $label' : null
        : null,
    builder: (FormFieldState<DateTime> state) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: GestureDetector(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: Colors.grey.withAlpha(26),
              suffixIcon: const Icon(Icons.calendar_today),
              errorText: state.errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            child: Text(
              state.value != null
                  ? DateFormat.yMd().format(state.value!)
                  : 'Select a date',
              style: TextStyle(
                color: state.value != null
                    ? null
                    : Colors.grey,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class CustomDropdownField extends StatelessWidget {
  final String label;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool isRequired;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          label: _buildLabel(label, isRequired), // Used label instead of labelText
          filled: true,
          fillColor: Colors.grey.withAlpha(26),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        initialValue: items.contains(value) ? value : null,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        validator: (val) {
          if (isRequired && (val == null || val.isEmpty)) {
            return "Please select $label";
          }
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }
}

class CustomApiDropdownField extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> items;
  final int? value;
  final bool isRequired;
  final ValueChanged<int?> onChanged;
  final bool includeOther;
  final int otherId;

  const CustomApiDropdownField({
    super.key,
    required this.label,
    this.isRequired = false,
    required this.items,
    required this.value,
    required this.onChanged,
    this.includeOther = false,
    this.otherId = -1,
  });

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<int>> dropdownItems = items
        .map(
          (item) => DropdownMenuItem<int>(
            value: item['id'],
            child: Text(
              item['name'],
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();

    if (includeOther) {
      dropdownItems.add(
        DropdownMenuItem<int>(value: otherId, child: const Text('Other...')),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<int>(
        decoration: InputDecoration(
          label: _buildLabel(label, isRequired), // Used label instead of labelText
          filled: true,
          fillColor: Colors.grey.withAlpha(26),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        isExpanded: true,
        initialValue: dropdownItems.any((item) => item.value == value)
            ? value
            : null,
        items: dropdownItems,
        onChanged: onChanged,
        validator: (val) {
          if (isRequired && val == null) {
            return "Please select $label";
          }
          return null;
        },
      ),
    );
  }
}

class CustomChoiceChipGroup extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? groupValue;
  final ValueChanged<String?> onChanged;
  final bool isRequired; // Added this to support asterisk on Choice Chips

  const CustomChoiceChipGroup({
    super.key,
    required this.title,
    required this.options,
    required this.groupValue,
    required this.onChanged,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildLabel(title, isRequired), // Added asterisk to the title
        ),
        Wrap(
          spacing: 8.0,
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
              backgroundColor: Colors.grey.withAlpha(26),
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
}

class CustomFilterChipGroup extends StatelessWidget {
  final String title;
  final List<String> options;
  final Set<String> selectedValues;
  final Function(String, bool) onChanged;
  final bool isRequired; // Added this to support asterisk on Filter Chips

  const CustomFilterChipGroup({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildLabel(title, isRequired), // Added asterisk to the title
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
              backgroundColor: Colors.grey.withAlpha(26),
              onSelected: (selected) {
                onChanged(option, selected);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}