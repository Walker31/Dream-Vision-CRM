import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../dialogs/user_selection_dialog.dart';
import '../Telecaller/follow_up_sheet.dart';
// Correct import based on the documentation
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

class EnquiryDetailPage extends StatefulWidget {
  final int enquiryId;

  const EnquiryDetailPage({super.key, required this.enquiryId});

  @override
  State<EnquiryDetailPage> createState() => _EnquiryDetailPageState();
}

class _EnquiryDetailPageState extends State<EnquiryDetailPage> {
  final EnquiryService _enquiryService = EnquiryService();
  late Future<Enquiry> _enquiryFuture;
  final Logger _logger = Logger();
  // Add a key to control the FAB programmatically (optional, but good practice)
  final _fabKey = GlobalKey<ExpandableFabState>();

  @override
  void initState() {
    super.initState();
    _enquiryFuture = _fetchEnquiryData();
  }

  Future<Enquiry> _fetchEnquiryData() async {
    try {
      final jsonData = await _enquiryService.getEnquiryById(widget.enquiryId);
      return Enquiry.fromJson(jsonData);
    } catch (e) {
      _logger.e('Failed to fetch enquiry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading enquiry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      rethrow;
    }
  }

  Future<void> _refreshEnquiryData() async {
    setState(() {
      _enquiryFuture = _fetchEnquiryData();
    });
  }

  // Helper to close the FAB after an action
  void _closeFab() {
    final state = _fabKey.currentState;
    if (state != null && state.isOpen) {
      state.toggle();
    }
  }

  void _goToEditPage(BuildContext context, Enquiry enquiry) async {
    _closeFab();
    final bool? result = await context.push<bool>(
      '/add-enquiry',
      extra: enquiry,
    );

    if (result == true && mounted) {
      _refreshEnquiryData();
    }
  }

  void _showAddFollowUpSheet(BuildContext context, Enquiry enquiry) async {
    _closeFab();
    final bool? didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AddFollowUpSheet(enquiry: enquiry);
      },
    );

    if (didSave == true && mounted) {
      _refreshEnquiryData();
    }
  }

  void _goToHistoryPage(BuildContext context, int enquiryId, String? fullName) {
    _closeFab();
    context.push('/follow-ups/$enquiryId', extra: fullName);
  }

  Future<void> _showUserSelectionDialog(
    BuildContext context,
    String role,
    int enquiryId,
  ) async {
    final selectedUserId = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return UserSelectionDialog(role: role, enquiryService: _enquiryService);
      },
    );

    if (selectedUserId != null && mounted) {
      _assignUserToEnquiry(role, selectedUserId, enquiryId);
    }
  }

  Future<void> _assignUserToEnquiry(
    String role,
    int userId,
    int enquiryId,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _enquiryService.assignEnquiry(
        enquiryId: enquiryId,
        counsellorId: role == 'Counsellor' ? userId : null,
        telecallerId: role == 'Telecaller' ? userId : null,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully assigned to $role!'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshEnquiryData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      _logger.e('Failed to assign $role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning $role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Enquiry>(
      future: _enquiryFuture,
      builder: (context, snapshot) {
        Enquiry? enquiry = snapshot.data;
        List<Widget> appBarActions = [];
        String? fullName;

        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            enquiry != null) {
          fullName = '${enquiry.firstName} ${enquiry.lastName ?? ''}'.trim();
          if (enquiry.assignedToCounsellorDetails == null) {
            appBarActions.add(
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Assign Counsellor'),
                onPressed: () =>
                    _showUserSelectionDialog(context, 'Counsellor', enquiry.id),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).appBarTheme.foregroundColor,
                ),
              ),
            );
          }
          if (enquiry.assignedToTelecallerDetails == null) {
            appBarActions.add(
              TextButton.icon(
                icon: const Icon(Icons.headset_mic_outlined),
                label: const Text('Assign Telecaller'),
                onPressed: () =>
                    _showUserSelectionDialog(context, 'Telecaller', enquiry.id),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).appBarTheme.foregroundColor,
                ),
              ),
            );
          }
        }

        return Scaffold(
          appBar: AppBar(
            leading: const BackButtonIos(),
            title: const Text('Enquiry Details'),
            elevation: 1,
            actions: appBarActions.isEmpty ? null : appBarActions,
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Failed to load enquiry: ${snapshot.error}'),
                  ),
                )
              : snapshot.hasData
              ? RefreshIndicator(
                  onRefresh: _refreshEnquiryData,
                  child: _buildDetailsView(context, enquiry!),
                )
              : const Center(child: Text('No enquiry data found.')),
          floatingActionButton: enquiry != null
              ? SpeedDial(
                  icon: Icons.add,
                  activeIcon: Icons.close,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  overlayColor: Colors.black,
                  overlayOpacity: 0.4,
                  spacing: 12,
                  spaceBetweenChildren: 12,
                  elevation: 6,
                  shape: const CircleBorder(),

                  children: [
                    SpeedDialChild(
                      child: const Icon(Icons.edit_outlined),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      label: 'Edit Enquiry',
                      labelStyle: const TextStyle(fontSize: 14),
                      onTap: () => _goToEditPage(context, enquiry),
                    ),
                    SpeedDialChild(
                      child: const Icon(Icons.history_outlined),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      label: 'View History',
                      labelStyle: const TextStyle(fontSize: 14),
                      onTap: () =>
                          _goToHistoryPage(context, enquiry.id, fullName),
                    ),
                    SpeedDialChild(
                      child: const Icon(Icons.add_comment_outlined),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      label: 'Add Follow-up',
                      labelStyle: const TextStyle(fontSize: 14),
                      onTap: () => _showAddFollowUpSheet(context, enquiry),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _buildDetailsView(BuildContext context, Enquiry enquiry) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, enquiry),
            const SizedBox(height: 24),
            _buildContactCard(enquiry),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Enquiry Details',
              icon: Icons.info_outline,
              details: {
                'Standard': enquiry.enquiringForStandard,
                'Board': enquiry.enquiringForBoard,
                'Competitive Exam': enquiry.enquiringForExam,
              },
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Personal Information',
              icon: Icons.person_outline,
              details: {
                'Date of Birth': enquiry.dateOfBirth,
                'School': enquiry.schoolName,
                'Address': enquiry.address,
                'Father\'s Occupation': enquiry.fatherOccupation,
              },
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Administrative Details',
              icon: Icons.admin_panel_settings_outlined,
              details: {
                'Source': enquiry.sourceName,
                'Assigned Counsellor': enquiry.assignedToCounsellorDetails,
                'Assigned Telecaller': enquiry.assignedToTelecallerDetails,
                'Registered On': enquiry.createdAt.split('T').first,
              },
            ),
            const SizedBox(height: 80), // Padding for the FAB
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Enquiry enquiry) {
    final fullName = '${enquiry.firstName} ${enquiry.lastName ?? ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fullName,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            if (enquiry.currentStatusName != null)
              Chip(
                label: Text(enquiry.currentStatusName!),
                avatar: const Icon(Icons.flag_outlined, size: 18),
                backgroundColor: Colors.blue.shade50,
                labelStyle: TextStyle(color: Colors.blue.shade800),
              ),
            if (enquiry.leadTemperature != null)
              Chip(
                label: Text(enquiry.leadTemperature!),
                avatar: const Icon(Icons.thermostat_outlined, size: 18),
                backgroundColor: _getTemperatureColor(
                  enquiry.leadTemperature!,
                ).withAlpha(25),
                labelStyle: TextStyle(
                  color: _getTemperatureColor(enquiry.leadTemperature!),
                ),
              ),
            if (enquiry.isAdmissionConfirmed)
              Chip(
                label: const Text('Admission Confirmed'),
                avatar: const Icon(Icons.check_circle_outline, size: 18),
                backgroundColor: Colors.green.shade50,
                labelStyle: TextStyle(color: Colors.green.shade800),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactCard(Enquiry enquiry) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _buildContactTile(
              icon: Icons.phone_outlined,
              value: enquiry.phoneNumber,
              label: 'Primary Phone',
            ),
            if (enquiry.email != null && enquiry.email!.isNotEmpty)
              _buildContactTile(
                icon: Icons.email_outlined,
                value: enquiry.email!,
                label: 'Email',
              ),
            if (enquiry.fatherPhoneNumber != null &&
                enquiry.fatherPhoneNumber!.isNotEmpty)
              _buildContactTile(
                icon: Icons.phone_android_outlined,
                value: enquiry.fatherPhoneNumber!,
                label: "Father's Phone",
              ),
            if (enquiry.motherPhoneNumber != null &&
                enquiry.motherPhoneNumber!.isNotEmpty)
              _buildContactTile(
                icon: Icons.phone_android_outlined,
                value: enquiry.motherPhoneNumber!,
                label: "Mother's Phone",
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(value),
      subtitle: Text(label),
      dense: true,
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Map<String, dynamic> details,
  }) {
    final validDetails = details.entries
        .where(
          (entry) =>
              entry.value != null &&
              (entry.value is Map ||
                  (entry.value is String && entry.value!.isNotEmpty)),
        )
        .toList();

    if (validDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.indigo.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 0.5),
            ...validDetails.map((entry) {
              Widget valueWidget;
              if (entry.value is Map) {
                final userData = entry.value as Map<String, dynamic>;
                final name = userData['full_name'] ?? 'N/A';
                final role = userData['role'] ?? '';
                valueWidget = Text(
                  '$name ${role.isNotEmpty ? '($role)' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                );
              } else {
                valueWidget = Text(
                  entry.value?.toString() ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${entry.key}:',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: valueWidget),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getTemperatureColor(String? temp) {
    switch (temp?.toLowerCase()) {
      case 'hot':
        return Colors.red.shade700;
      case 'warm':
        return Colors.orange.shade700;
      case 'cold':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
