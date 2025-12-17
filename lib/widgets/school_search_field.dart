import 'package:flutter/material.dart';

class SearchableSchoolField extends StatefulWidget {
  final List<Map<String, dynamic>> schools;
  final int? value;
  final ValueChanged<int?> onChanged;
  final TextEditingController controller;

  static const int otherSchoolId = -1;

  const SearchableSchoolField({
    super.key,
    required this.schools,
    required this.value,
    required this.onChanged,
    required this.controller,
  });

  @override
  State<SearchableSchoolField> createState() => _SearchableSchoolFieldState();
}

class _SearchableSchoolFieldState extends State<SearchableSchoolField> {
  late final FocusNode _focusNode;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _overlay?.remove();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: widget.controller,
      focusNode: _focusNode,

      // ==== OPTIONS LOGIC ====
      optionsBuilder: (TextEditingValue value) {
        final pattern = value.text.trim().toLowerCase();
        if (pattern.isEmpty) return const Iterable.empty();

        // Filter
        final results = widget.schools.where((s) {
          return s['name'].toString().toLowerCase().contains(pattern);
        }).toList();

        // Add "Create school" option
        if (!results.any((s) => s['name'].toLowerCase() == pattern)) {
          results.add({
            'id': SearchableSchoolField.otherSchoolId,
            'name': 'Add School: "${value.text}"',
            'raw': value.text,
          });
        }

        return results;
      },

      displayStringForOption: (item) => item['name'],

      // ==== TEXT FIELD ====
      fieldViewBuilder: (context, controller, focusNode, submit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: "School",
            filled: true,
            fillColor: Colors.grey.withAlpha(26),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      widget.onChanged(null);
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        );
      },

      // ==== DROPDOWN UI ====
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);

                  return InkWell(
                    onTap: () {
                      // Add School
                      if (option['id'] == SearchableSchoolField.otherSchoolId) {
                        widget.controller.text = option['raw'];
                        widget.onChanged(SearchableSchoolField.otherSchoolId);
                      } else {
                        widget.controller.text = option['name'];
                        widget.onChanged(option['id']);
                      }
                      onSelected(option);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      child: Text(option['name']),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
