// ignore_for_file: use_build_context_synchronously

import 'package:dreamvision/utils/global_error_handler.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../../models/enquiry_model.dart';
import '../../models/follow_up_model.dart';
import '../../services/enquiry_service.dart';
import '../../widgets/form_widgets.dart';

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

class _AddFollowUpSheetState extends State<AddFollowUpSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Logger logger = Logger();

  final EnquiryService _service = EnquiryService();

  bool _isLoading = false;
  bool _isCnr = false;

  // Academic fields
  String? _standard;
  String? _board;
  bool? _admissionConfirmed;
  final Set<int> _selectedExamIds = {};
  List<Map<String, dynamic>> _exams = [];

  final TextEditingController _remarksController = TextEditingController();

  // Status items
  List<dynamic> _statuses = [];
  int? _selectedStatusId;
  bool _isStatusLoaded = false;

  DateTime? _nextFollowUpDate;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _loadInitialValues();
    _loadStatuses();
    _loadExams();
  }

  void _loadInitialValues() {
    if (widget.existingFollowUp == null) {
      _standard = widget.enquiry.enquiringForStandard;
      _board = widget.enquiry.enquiringForBoard;
      _admissionConfirmed = widget.enquiry.isAdmissionConfirmed;
      return;
    }

    final f = widget.existingFollowUp!;

    _remarksController.text = f.remarks;
    _isCnr = f.cnr;

    if (f.nextFollowUpDate != null) {
      try {
        _nextFollowUpDate = DateTime.parse(f.nextFollowUpDate!);
      } catch (_) {}
    }

    final acad = f.academicDetailsDiscussed;
    _standard = acad['standard'];
    _board = acad['board'];
    _admissionConfirmed = acad['admission_confirmed'];

    if (acad['exams'] is List) {
      _selectedExamIds.addAll(
        (acad['exams'] as List)
            .map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? 0)
            .where((id) => id > 0),
      );
    }
  }

  Future<void> _loadStatuses() async {
    try {
      _statuses = await _service.getEnquiryStatuses();

      if (widget.existingFollowUp != null &&
          widget.existingFollowUp!.statusAfterFollowUp != null) {
        final name = widget.existingFollowUp!.statusAfterFollowUp!
            .toLowerCase();

        final match = _statuses.firstWhere(
          (s) {
            if (s is! Map<String, dynamic>) return false;
            final statusName = s['name'];
            return statusName is String && statusName.toLowerCase() == name;
          },
          orElse: () => null,
        );

        if (match != null && match is Map<String, dynamic>) {
          _selectedStatusId = match['id'];
        }
      }
    } catch (e) {
      logger.e("Status load error: $e");
    } finally {
      if (mounted) {
        _isStatusLoaded = true;
        setState(() {});
      }
    }
  }

  Future<void> _loadExams() async {
    try {
      final exams = await _service.getExams();
      if (mounted) {
        setState(() {
          _exams = List<Map<String, dynamic>>.from(exams);
        });
      }
    } catch (e) {
      logger.e("Exams load error: $e");
    }
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          _nextFollowUpDate ?? DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: _nextFollowUpDate != null
          ? TimeOfDay.fromDateTime(_nextFollowUpDate!)
          : const TimeOfDay(hour: 11, minute: 0),
    );

    if (t == null) return;

    setState(() {
      _nextFollowUpDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  void _clearAcademic() {
    _standard = null;
    _board = null;
    _selectedExamIds.clear();
    _admissionConfirmed = null;
  }

  Future<void> _submit() async {
    if (!_isCnr && !_formKey.currentState!.validate()) return;

    if (_isLoading) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> payload;

    if (_isCnr) {
      final cnrStatus = _statuses.firstWhere(
        (s) => (s['name'] as String).toLowerCase() == 'cnr',
        orElse: () => null,
      );

      payload = {
        "enquiry": widget.enquiry.id,
        "remarks": "CNR (Contact Not Received)",
        "cnr": true,
        "next_follow_up_date": null,
        "status_after_follow_up": cnrStatus?['id'],
        "academic_details_discussed": null,
      };
    } else {
      payload = {
        "enquiry": widget.enquiry.id,
        "remarks": _remarksController.text.trim(),
        "cnr": false,
        "status_after_follow_up": _selectedStatusId,
        "next_follow_up_date": _nextFollowUpDate?.toIso8601String(),
        "academic_details_discussed": {
          "standard": _standard,
          "board": _board,
          "exams": _selectedExamIds.toList(),
          "admission_confirmed": _admissionConfirmed,
        },
      };
    }

    try {
      if (widget.existingFollowUp == null) {
        await _service.addFollowUp(payload);
      } else {
        await _service.updateFollowUp(widget.existingFollowUp!.id, payload);
      }

      if (mounted) {
        Navigator.pop(context, true);
        GlobalErrorHandler.success(
          widget.existingFollowUp == null
              ? "Follow-up saved!"
              : "Follow-up updated!",
        );
      }
    } catch (e) {
      logger.e("Save error: $e");
      if (mounted) {
        GlobalErrorHandler.error('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // UI building
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _header(),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _info(
                          "Student Name",
                          "${widget.enquiry.firstName} ${widget.enquiry.lastName}"
                              .trim(),
                        ),
                        _info("Mobile No.", widget.enquiry.phoneNumber ?? '-'),
                        const SizedBox(height: 10),
                        _section("Follow-up Details"),
                        _cnrToggle(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _isCnr
                              ? const SizedBox.shrink()
                              : FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: _nonCnrSection(),
                                ),
                        ),
                        const SizedBox(height: 20),
                        _saveBtn(cs),
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

  Widget _nonCnrSection() {
    _animController.forward();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusDropdown(),
        const SizedBox(height: 16),
        _datePicker(),
        const SizedBox(height: 12),

        CustomTextField(_remarksController, "Feedback / Remarks", maxLines: 3),

        const SizedBox(height: 20),
        _section("Academic & Admission Details"),

        CustomChoiceChipGroup(
          title: "Standard",
          options: ["12th", "11th", "10th", "9th", "8th"],
          groupValue: _standard,
          onChanged: (v) => setState(() => _standard = v),
        ),

        const SizedBox(height: 12),
        CustomChoiceChipGroup(
          title: "Board",
          options: ["SSC", "ICSE", "CBSE"],
          groupValue: _board,
          onChanged: (v) => setState(() => _board = v),
        ),

        const SizedBox(height: 12),
        CustomFilterChipGroup(
          title: "Exam",
          options: _exams.map((e) => e['name'] as String).toList(),
          selectedValues: _exams
              .where((e) => _selectedExamIds.contains(e['id']))
              .map((e) => e['name'] as String)
              .toSet(),
          onChanged: (examName, selected) {
            setState(() {
              final exam = _exams.firstWhere((e) => e['name'] == examName);
              if (selected) {
                _selectedExamIds.add(exam['id'] as int);
              } else {
                _selectedExamIds.remove(exam['id'] as int);
              }
            });
          },
        ),

        const SizedBox(height: 12),
        CustomChoiceChipGroup(
          title: "Admission Confirmed",
          options: ["Yes", "No"],
          groupValue: _admissionConfirmed == null
              ? null
              : (_admissionConfirmed! ? "Yes" : "No"),
          onChanged: (v) => setState(() {
            _admissionConfirmed = (v == "Yes");
          }),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.existingFollowUp == null
              ? "Enquiry Follow-up"
              : "Edit Follow-up",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _info(String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(color: Theme.of(context).hintColor)),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _cnrToggle() {
    return SwitchListTile(
      title: const Text(
        "CNR (Contact Not Received)",
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      value: _isCnr,
      onChanged: (v) {
        setState(() {
          _isCnr = v;
          if (v) {
            _clearAcademic();
            _animController.reverse();
          } else {
            _animController.forward();
          }
        });
      },
      secondary: Icon(
        Icons.phone_missed,
        color: _isCnr ? Colors.red : Colors.grey,
      ),
    );
  }

  Widget _statusDropdown() {
    if (!_isStatusLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_statuses.isEmpty) {
      return const Text("No statuses available.");
    }

    return CustomApiDropdownField(
      label: "New Status",
      items: List<Map<String, dynamic>>.from(_statuses),
      value: _selectedStatusId,
      onChanged: (v) => setState(() => _selectedStatusId = v),
    );
  }

  Widget _datePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Next Follow-up Date & Time",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDateTime,
          child: Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _nextFollowUpDate == null
                      ? "Select date & time (Optional)"
                      : DateFormat.yMMMd().add_jm().format(_nextFollowUpDate!),
                ),
                const Icon(Icons.calendar_today_outlined),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveBtn(ColorScheme cs) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Text(
              widget.existingFollowUp == null
                  ? "Save Follow-up"
                  : "Update Follow-up",
            ),
    );
  }
}
