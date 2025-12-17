import 'package:flutter/material.dart';

extension Cap on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class EnquiryFilterBottomSheet extends StatefulWidget {
  final String? initialStandard;
  final String? initialStatus;
  final List<String> standardOptions;
  final List<String> statusOptions;
  final Function(String? standard, String? status) onApplyFilters;
  final VoidCallback onClearFilters;

  const EnquiryFilterBottomSheet({
    super.key,
    required this.initialStandard,
    required this.initialStatus,
    required this.standardOptions,
    required this.statusOptions,
    required this.onApplyFilters,
    required this.onClearFilters,
  });

  @override
  State<EnquiryFilterBottomSheet> createState() =>
      _EnquiryFilterBottomSheetState();
}

class _EnquiryFilterBottomSheetState extends State<EnquiryFilterBottomSheet> {
  String? _selectedStandard;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStandard = widget.initialStandard;
    _selectedStatus = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Grab handle ---
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // --- Header ---
            Row(
              children: [
                const Text(
                  "Filters",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onClearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text("Reset"),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // -------------------
            //     STANDARD
            // -------------------
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Standard",
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: widget.standardOptions.map((std) {
                final selected = _selectedStandard == std;

                return ChoiceChip(
                  label: Text(
                    std,
                    style: TextStyle(
                      color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                  selected: selected,
                  selectedColor: cs.primary,
                  backgroundColor: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedStandard = selected ? null : std;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 22),

            // -------------------
            //       STATUS
            // -------------------
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Status",
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: widget.statusOptions.map((s) {
                final selected = _selectedStatus == s;

                return ChoiceChip(
                  label: Text(
                    s.capitalize(),
                    style: TextStyle(
                      color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                  selected: selected,
                  selectedColor: cs.primary,
                  backgroundColor: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus = selected ? null : s;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // -------------------
            //    Apply Button
            // -------------------
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApplyFilters(_selectedStandard, _selectedStatus);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Apply Filters"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
