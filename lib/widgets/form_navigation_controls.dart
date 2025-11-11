// FILE: lib/features/enquiry/widgets/form_navigation_controls.dart

import 'package:flutter/material.dart';

class FormNavigationControls extends StatelessWidget {
  final int currentPage;
  final bool isSubmitting;
  final bool isEditMode;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const FormNavigationControls({
    super.key,
    required this.currentPage,
    required this.isSubmitting,
    required this.isEditMode,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withAlpha(51), width: 1.0),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Opacity(
              opacity: currentPage > 0 ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: currentPage == 0,
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  label: const Text('Back'),
                  onPressed: isSubmitting ? null : onBack,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => _buildDotIndicator(context, index),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : onNext,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSubmitting
                        ? 'Saving...'
                        : (currentPage == 2
                              ? (isEditMode ? 'Update' : 'Submit')
                              : 'Next'),
                  ),
                  const SizedBox(width: 8),
                  isSubmitting
                      ? Container(
                          width: 18,
                          height: 18,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDotIndicator(BuildContext context, int index) {
    bool isActive = currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: isActive ? 12.0 : 8.0,
      height: isActive ? 12.0 : 8.0,
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade400,
      ),
    );
  }
}
