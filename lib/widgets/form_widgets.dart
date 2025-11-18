// FILE: lib/widgets/form_widgets.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.withAlpha(26),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          // Required check
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }

          if (value == null || value.isEmpty) return null;

          final digits = value.replaceAll(RegExp(r'\D'), '');

          // PHONE VALIDATION - 10 digits
          if (validatorType == "phone") {
            if (digits.length != 10) {
              return 'Please enter a valid mobile number.';
            }
          }

          // PINCODE VALIDATION - 6 digits
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

class CustomDateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const CustomDateField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today),
            filled: true,
            fillColor: Colors.grey.withAlpha(26),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          child: Text(
            date != null ? DateFormat.yMd().format(date!) : 'Select a date',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class CustomDropdownField extends StatelessWidget {
  final String label;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.withAlpha(26),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        initialValue: items.contains(value) ? value : null,
        items: items
            .map(
              (item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class CustomApiDropdownField extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> items;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool includeOther;
  final int otherId;

  const CustomApiDropdownField({
    super.key,
    required this.label,
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
              // FIX 2: Handle long text in the menu
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
          labelText: label,
          filled: true,
          fillColor: Colors.grey.withAlpha(26),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),

        // FIX 1: Force the dropdown to fill its parent's width
        isExpanded: true,

        initialValue: dropdownItems.any((item) => item.value == value)
            ? value
            : null,
        items: dropdownItems,
        onChanged: onChanged,
      ),
    );
  }
}

class CustomChoiceChipGroup extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  const CustomChoiceChipGroup({
    super.key,
    required this.title,
    required this.options,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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

  const CustomFilterChipGroup({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
