import 'package:flutter/material.dart';

class EnquiryFilterBottomSheet extends StatefulWidget {
  final Set<String> initialStandards;
  final Set<String> initialStatuses;
  final int? initialTelecallerId;
  final List<String> standardOptions;
  final Map<String, int> statusCounts;
  final List<Map<String, dynamic>>? telecallerOptions;
  final bool isLoadingTelecallers;
  final Function(Set<String> standards, Set<String> statuses, [int? telecallerId, String? teleName]) onApplyFilters;
  final VoidCallback onClearFilters;

  const EnquiryFilterBottomSheet({
    super.key,
    required this.initialStandards,
    required this.initialStatuses,
    this.initialTelecallerId,
    required this.standardOptions,  
    required this.statusCounts,
    this.telecallerOptions,
    this.isLoadingTelecallers = false,
    required this.onApplyFilters,
    required this.onClearFilters,
  });

  @override
  State<EnquiryFilterBottomSheet> createState() =>
      _EnquiryFilterBottomSheetState();
}

class _EnquiryFilterBottomSheetState extends State<EnquiryFilterBottomSheet> {
  Set<String> _selectedStandards = {};
  Set<String> _selectedStatuses = {};
  int? _selectedTelecallerId;
  String? _selectedTelecallerName;
  final bool _isLoadingStatuses = false;

  @override
  void initState() {
    super.initState();
    _selectedStandards = widget.initialStandards;
    _selectedStatuses = widget.initialStatuses;
    _selectedTelecallerId = widget.initialTelecallerId;
    // Find telecaller name from options
    if (_selectedTelecallerId != null && widget.telecallerOptions != null) {
      for (var tc in widget.telecallerOptions!) {
        if (tc['id'] == _selectedTelecallerId) {
          _selectedTelecallerName = tc['user']?['first_name'] ?? tc['user']?['username'] ?? 'Unknown';
          break;
        }
      }
    }
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
                final selected = _selectedStandards.contains(std);

                return ChoiceChip(
                  showCheckmark: false,
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
                      if (selected) {
                        _selectedStandards.remove(std);
                      } else {
                        _selectedStandards.add(std);
                      }
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

            if (_isLoadingStatuses)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              )
            else if (widget.statusCounts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No statuses available',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: widget.statusCounts.entries.map((entry) {
                  final status = entry.key;
                  final count = entry.value;
                  final selected = _selectedStatuses.contains(status);

                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      '${status[0].toUpperCase()}${status.substring(1)} ($count)',
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
                        if (selected) {
                          _selectedStatuses.remove(status);
                        } else {
                          _selectedStatuses.add(status);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

            const SizedBox(height: 22),

            // -------------------
            //     TELECALLER
            // -------------------
            if (widget.telecallerOptions != null && widget.telecallerOptions!.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Telecaller",
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (widget.isLoadingTelecallers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                )
              else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Clear selection option
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: const Text('All'),
                        selected: _selectedTelecallerId == null,
                        selectedColor: cs.primary,
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedTelecallerId = null;
                            _selectedTelecallerName = null;
                          });
                        },
                      ),
                    ),
                    // Telecaller options
                    ...widget.telecallerOptions!.map((tc) {
                      final tcId = tc['id'];
                      final tcName = tc['user']?['first_name'] ?? tc['user']?['username'] ?? 'Unknown';
                      final selected = _selectedTelecallerId == tcId;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          showCheckmark: false,
                          label: Text(
                            tcName,
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
                              _selectedTelecallerId = selected ? null : tcId;
                              _selectedTelecallerName = selected ? null : tcName;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // -------------------
            //    Apply Button
            // -------------------
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApplyFilters(_selectedStandards, _selectedStatuses, _selectedTelecallerId, _selectedTelecallerName);
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
