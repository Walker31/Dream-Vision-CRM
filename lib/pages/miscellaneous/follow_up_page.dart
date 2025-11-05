import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../services/enquiry_service.dart';
import '../../widgets/back_button.dart';

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
      remarks: json['remarks']?.isNotEmpty == true
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
  final EnquiryService _enquiryService = EnquiryService();
  late Future<List<FollowUp>> _followUpsFuture;
  Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchFollowUps();
  }

  void _fetchFollowUps() {
    _followUpsFuture = _enquiryService
        .getFollowUpsForEnquiry(widget.enquiryId)
        .then((data) => data.map((item) => FollowUp.fromJson(item)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonIos(),
        title: const Text('Follow-up History'),
      ),
      body: FutureBuilder<List<FollowUp>>(
        future: _followUpsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load follow-ups: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No follow-ups have been recorded yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final followUps = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: followUps.length,
            itemBuilder: (context, index) {
              return _TimelineTile(
                followUp: followUps[index],
                isFirst: index == 0,
                isLast: index == followUps.length - 1,
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

  _TimelineTile({
    required this.followUp,
    this.isFirst = false,
    this.isLast = false,
  });

  final Logger logger = Logger();
  

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimelineConnector(context),
          const SizedBox(width: 16),
          Expanded(child: _buildTimelineContent(context)),
        ],
      ),
    );
  }

  Widget _buildTimelineConnector(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            width: 2,
            color: isFirst ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFirst
                ? Theme.of(context).primaryColor
                : Colors.grey.shade400,
          ),
        ),
        Expanded(
          child: Container(
            width: 2,
            color: isLast ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.yMMMd().add_jm().format(followUp.timestamp),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isFirst
                      ? Theme.of(context).primaryColor
                      : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const Divider(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.person_outline,
                label: 'By:',
                value: followUp.user?.fullName ?? 'N/A',
              ),
              const SizedBox(height: 8),
              _buildStatusChange(context),
              const SizedBox(height: 12),
              Text(
                followUp.remarks,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              if (followUp.nextFollowUpDate != null) ...[
                const SizedBox(height: 12),
                _buildNextFollowUp(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChange(BuildContext context) {
    final before = followUp.statusBeforeFollowUpName;
    final after = followUp.statusAfterFollowUp;

    if (after == null) {
      return _buildInfoRow(
        context,
        icon: Icons.flag_outlined,
        label: 'Status:',
        value: 'Not recorded',
      );
    }

    if (before == after) {
      return _buildInfoRow(
        context,
        icon: Icons.flag_outlined,
        label: 'Status:',
        value: "Kept as '$after'",
      );
    }

    if (before == null) {
      return _buildInfoRow(
        context,
        icon: Icons.flag_outlined,
        label: 'Status:',
        value: "Set to '$after'",
        valueColor: Theme.of(context).primaryColor,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.change_history_outlined,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          "Status:",
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(
                context,
              ).style.copyWith(fontWeight: FontWeight.w500),
              children: [
                TextSpan(
                  text: before,
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                TextSpan(
                  text: ' ➔ ',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
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

  Widget _buildNextFollowUp() {
    final nextDate = DateTime.parse(followUp.nextFollowUpDate!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_repeat_outlined,
            color: Colors.amber.shade800,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Next Follow-up: ${DateFormat.yMMMd().add_jm().format(nextDate)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
