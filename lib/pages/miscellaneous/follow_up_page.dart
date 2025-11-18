import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/enquiry_service.dart';
import '../../widgets/back_button.dart';
import '../../models/enquiry_model.dart';
import '../Telecaller/follow_up_sheet.dart';

// ------------------------------------------------------
// Model Classes
// ------------------------------------------------------

class FollowUpUser {
  final String fullName;
  FollowUpUser({required this.fullName});

  factory FollowUpUser.fromJson(Map<String, dynamic> json) {
    return FollowUpUser(fullName: json['full_name'] ?? 'Unknown User');
  }
}

class FollowUp {
  final int id;
  final String remarks;
  final String? statusBeforeFollowUpName;
  final String? statusAfterFollowUp;
  final String? nextFollowUpDate;
  final DateTime timestamp;
  final FollowUpUser? user;

  FollowUp({
    required this.id,
    required this.remarks,
    this.statusBeforeFollowUpName,
    this.statusAfterFollowUp,
    this.nextFollowUpDate,
    required this.timestamp,
    this.user,
  });

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    return FollowUp(
      id: json['id'],
      remarks: (json['remarks'] ?? '').isNotEmpty
          ? json['remarks']
          : 'No remarks provided.',
      statusBeforeFollowUpName: json['status_before_follow_up_name'],
      statusAfterFollowUp: json['status_after_follow_up_name'],
      nextFollowUpDate: json['next_follow_up_date'],
      timestamp: DateTime.parse(json['timestamp']),
      user: json['user'] != null ? FollowUpUser.fromJson(json['user']) : null,
    );
  }
}

// ------------------------------------------------------
// FollowUp Page
// ------------------------------------------------------

class FollowUpPage extends StatefulWidget {
  final int enquiryId;
  final String enquiryName;

  const FollowUpPage({
    super.key,
    required this.enquiryId,
    required this.enquiryName,
  });

  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  final EnquiryService _service = EnquiryService();
  late Future<List<FollowUp>> _followUps;

  @override
  void initState() {
    super.initState();
    _loadFollowUps();
  }

  void _loadFollowUps() {
    _followUps = _service
        .getFollowUpsForEnquiry(widget.enquiryId)
        .then((list) => list.map((e) => FollowUp.fromJson(e)).toList());
  }

  Future<void> _openEditor(FollowUp? followUp) async {
    try {
      final enquiryData = await _service.getEnquiryById(widget.enquiryId);
      final enquiry = Enquiry.fromJson(enquiryData);
      if (mounted) {
        final result = await showModalBottomSheet<bool?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              AddFollowUpSheet(enquiry: enquiry, existingFollowUp: followUp),
        );
        if (mounted && result == true) {
          setState(() => _loadFollowUps());
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open editor: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: cs.surface,
        leading: const BackButtonIos(),
        title: const Text('Follow-up History'),
      ),
      body: FutureBuilder<List<FollowUp>>(
        future: _followUps,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load follow-ups:\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error),
                ),
              ),
            );
          }

          final data = snap.data!;
          if (data.isEmpty) {
            return Center(
              child: Text(
                'No follow-ups recorded yet.',
                style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, i) {
              return _TimelineTile(
                followUp: data[i],
                isFirst: i == 0,
                isLast: i == data.length - 1,
                onEdit: () => _openEditor(data[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final FollowUp followUp;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;

  const _TimelineTile({
    required this.followUp,
    required this.onEdit,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final time = followUp.timestamp.toLocal();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConnector(context),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onLongPress: () {
                    onEdit();
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Opening follow-up…'),
                          duration: Duration(milliseconds: 600),
                        ),
                      );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat.yMMMd().add_jm().format(time),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isFirst ? cs.primary : cs.onSurface,
                            fontSize: 16,
                          ),
                        ),

                        Divider(color: cs.outlineVariant),

                        _info(
                          context,
                          icon: Icons.person_outline,
                          label: "By:",
                          value: followUp.user?.fullName ?? "N/A",
                        ),
                        const SizedBox(height: 8),

                        _status(context),
                        const SizedBox(height: 12),

                        Text(
                          followUp.remarks,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),

                        if (followUp.nextFollowUpDate != null) ...[
                          const SizedBox(height: 12),
                          _nextFollowUp(context),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CONNECTOR
  Widget _buildConnector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: Container(
            width: 2,
            color: isFirst ? Colors.transparent : cs.outlineVariant,
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFirst ? cs.primary : cs.outline,
          ),
        ),
        Expanded(
          child: Container(
            width: 2,
            color: isLast ? Colors.transparent : cs.outlineVariant,
          ),
        ),
      ],
    );
  }

  // STATUS CHANGE DISPLAY
  Widget _status(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final before = followUp.statusBeforeFollowUpName;
    final after = followUp.statusAfterFollowUp;

    if (after == null) {
      return _info(
        context,
        icon: Icons.flag_outlined,
        label: "Status:",
        value: "Not recorded",
        valueColor: cs.onSurfaceVariant,
      );
    }

    if (before == after) {
      return _info(
        context,
        icon: Icons.flag_outlined,
        label: "Status:",
        value: "Kept as '$after'",
      );
    }

    if (before == null) {
      return _info(
        context,
        icon: Icons.flag_outlined,
        label: "Status:",
        value: "Set to '$after'",
        valueColor: cs.primary,
      );
    }

    return Row(
      children: [
        Icon(
          Icons.change_history_outlined,
          size: 16,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          "Status:",
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: before,
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                TextSpan(
                  text: " ➜ ",
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: after,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // NEXT FOLLOW-UP BOX
  Widget _nextFollowUp(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateTime.parse(followUp.nextFollowUpDate!).toLocal();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.event_repeat_outlined, size: 20, color: cs.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Next Follow-up: ${DateFormat.yMMMd().add_jm().format(date)}",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // REUSABLE ROW
  Widget _info(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
