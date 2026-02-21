// ignore_for_file: use_build_context_synchronously

import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/utils/global_error_handler.dart';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../dialogs/user_selection_dialog.dart';
import '../../widgets/delete_confirmation_dialog.dart';
import '../Telecaller/follow_up_sheet.dart';
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
  Logger logger  = Logger();
  final Logger _logger = Logger();
  final _fabKey = GlobalKey<ExpandableFabState>();

  @override
  void initState() {
    super.initState();
    _enquiryFuture = _fetchEnquiryData();
  }

  Future<Enquiry> _fetchEnquiryData() async {
    try {
      final jsonData = await _enquiryService.getEnquiryById(widget.enquiryId);
      logger.d (jsonData);
      return Enquiry.fromJson(jsonData);
      
    } catch (e) {
      _logger.e('Failed to fetch enquiry: $e');
      if (mounted) {
        GlobalErrorHandler.error('Error loading enquiry: $e');
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
        GlobalErrorHandler.success(
          'Successfully assigned to $role!');
        _refreshEnquiryData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      _logger.e('Failed to assign $role: $e');
      if (mounted) {
        GlobalErrorHandler.error('Error assigning $role: $e');
      }
    }
  }

  Future<void> _deleteEnquiry(int id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _enquiryService.softDeleteEnquiry(id);

      if (mounted) Navigator.pop(context); // close loader
      if (mounted) Navigator.pop(context, true); // go back
      GlobalErrorHandler.success('Enquiry deleted successfully!');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      GlobalErrorHandler.error('Failed to delete enquiry');
    }
  }

  void _showDeleteEnquiryDialog(Enquiry enquiry) {
    showDialog(
      context: context,
      builder: (context) {
        return DeleteConfirmationDialog(
          title: "Confirm Deletion",
          message:
              "Are you sure you want to delete the enquiry for ${enquiry.firstName} ${enquiry.lastName ?? ''}? This cannot be undone.",
          onConfirm: () async {
            await _deleteEnquiry(enquiry.id);
          },
        );
      },
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    try {
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          GlobalErrorHandler.error('Could not launch call');
        }
      }
    } catch (e) {
      _logger.e('Error making call: $e');
      if (mounted) {
        GlobalErrorHandler.error('Error making call: $e');
      }
    }
  }



  Future<void> _closeEnquiry(Enquiry enquiry) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Close Enquiry'),
          content: Text(
            'Are you sure you want to close this enquiry for ${enquiry.firstName}? '
            'This will mark it as closed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateEnquiryStatus(enquiry.id, 'closed');
                _refreshEnquiryData();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateEnquiryStatus(int enquiryId, String newStatus) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _enquiryService.updateEnquiry(
        enquiryId,
        {'current_status': newStatus},
      );

      if (mounted) Navigator.pop(context);
      GlobalErrorHandler.success('Enquiry status updated successfully!');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _logger.e('Failed to update enquiry status: $e');
      GlobalErrorHandler.error('Failed to update status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
          
          // Only show "Assign Counsellor" button for Admin/Manager roles
          // (Counsellors can now access all enquiries, so no assignment needed)
          if (enquiry.assignedToTelecallerDetails == null) {
            appBarActions.add(
              TextButton.icon(
                icon: const Icon(Icons.headset_mic_outlined),
                label: const Text('Assign Telecaller'),
                onPressed: () =>
                    _showUserSelectionDialog(context, 'Telecaller', enquiry.id),
                style: TextButton.styleFrom(foregroundColor: cs.primary),
              ),
            );
          }
        }

        return Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: cs.surface,
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
                    child: Text(
                      'Failed to load enquiry: ${snapshot.error}',
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                )
              : snapshot.hasData
              ? RefreshIndicator(
                  onRefresh: _refreshEnquiryData,
                  child: _buildDetailsView(context, enquiry!),
                )
              : Center(
                  child: Text(
                    'No enquiry data found.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
          floatingActionButton: enquiry != null
              ? SpeedDial(
                  icon: Icons.menu,
                  activeIcon: Icons.close,
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  overlayColor: Colors.black,
                  overlayOpacity: 0.4,
                  spacing: 12,
                  spaceBetweenChildren: 12,
                  elevation: 6,
                  shape: const CircleBorder(),
                  children: [
                    SpeedDialChild(
                      child: const Icon(Icons.call_outlined),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      label: 'Make Call',
                      labelStyle: const TextStyle(fontSize: 14),
                      onTap: () {
                        final phone = enquiry.phoneNumber;
                        if (phone != null && phone.isNotEmpty) {
                          _makeCall(phone);
                        } else {
                          GlobalErrorHandler.error('No phone number available');
                        }
                      },
                    ),
                    SpeedDialChild(
                      child: const Icon(Icons.edit_outlined),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      label: 'Edit Enquiry',
                      labelStyle: const TextStyle(fontSize: 14),
                      onTap: () => _goToEditPage(context, enquiry),
                    ),
                    if (enquiry.isAdmissionConfirmed)
                      SpeedDialChild(
                        child: const Icon(Icons.check_circle_outlined),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        label: 'Close Enquiry',
                        labelStyle: const TextStyle(fontSize: 14),
                        onTap: () => _closeEnquiry(enquiry),
                      ),
                    SpeedDialChild(
                      child: const Icon(Icons.add_outlined),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      label: 'Add Follow-up',
                      labelStyle: const TextStyle(fontSize: 14),
                      onTap: () => _showAddFollowUpSheet(context, enquiry),
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
                      child: const Icon(Icons.delete),
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      label: 'Delete',
                      labelStyle: const TextStyle(fontSize: 14),
                      onTap: () {
                        _showDeleteEnquiryDialog(enquiry);
                      },
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
            _buildContactCard(context, enquiry),
            const SizedBox(height: 16),
            _buildInfoCard(
              context: context,
              title: 'Enquiry Details',
              icon: Icons.info_outline,
              details: {
                'Standard': enquiry.enquiringForStandard,
                'Board': enquiry.enquiringForBoard,
                'Competitive Exams': enquiry.exams.isNotEmpty
                    ? enquiry.exams
                        .map((e) => e['name'] as String? ?? 'Unknown')
                        .join(', ')
                    : 'None',
              },
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context: context,
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
              context: context,
              title: 'Administrative Details',
              icon: Icons.admin_panel_settings_outlined,
              details: {
                'Source': enquiry.sourceName,
                'Assigned Telecaller': enquiry.assignedToTelecallerDetails,
                'Created By': enquiry.createdByDetails,
                'Updated By': enquiry.updatedByDetails,   
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fullName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            if (enquiry.currentStatusName != null)
              Chip(
                label: Text(enquiry.currentStatusName!),
                avatar: Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                ),
                backgroundColor: isDark
                    ? Colors.blue.shade900.withAlpha(100)
                    : Colors.blue.shade50,
                labelStyle: TextStyle(
                  color: isDark ? Colors.blue.shade100 : Colors.blue.shade800,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            if (enquiry.leadTemperature != null)
              Chip(
                label: Text(enquiry.leadTemperature!),
                avatar: Icon(
                  Icons.thermostat_outlined,
                  size: 18,
                  color: _getTemperatureColor(
                    context,
                    enquiry.leadTemperature!,
                    true,
                  ),
                ),
                backgroundColor: _getTemperatureColor(
                  context,
                  enquiry.leadTemperature!,
                  false,
                ).withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: _getTemperatureColor(
                    context,
                    enquiry.leadTemperature!,
                    true,
                  ),
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            if (enquiry.isAdmissionConfirmed)
              Chip(
                label: const Text('Admission Confirmed'),
                avatar: Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: isDark ? Colors.green.shade200 : Colors.green.shade800,
                ),
                backgroundColor: isDark
                    ? Colors.green.shade900.withAlpha(100)
                    : Colors.green.shade50,
                labelStyle: TextStyle(
                  color: isDark ? Colors.green.shade100 : Colors.green.shade800,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactCard(BuildContext context, Enquiry enquiry) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            if (enquiry.phoneNumber != null && enquiry.phoneNumber!.isNotEmpty)
              _buildContactTile(
                context,
                icon: Icons.phone_outlined,
                value: enquiry.phoneNumber!,
                label: 'Primary Phone',
              ),
            if (enquiry.email != null && enquiry.email!.isNotEmpty)
              _buildContactTile(
                context,
                icon: Icons.email_outlined,
                value: enquiry.email!,
                label: 'Email',
              ),
            if (enquiry.fatherPhoneNumber != null &&
                enquiry.fatherPhoneNumber!.isNotEmpty)
              _buildContactTile(
                context,
                icon: Icons.phone_android_outlined,
                value: enquiry.fatherPhoneNumber!,
                label: "Father's Phone",
              ),
            if (enquiry.motherPhoneNumber != null &&
                enquiry.motherPhoneNumber!.isNotEmpty)
              _buildContactTile(
                context,
                icon: Icons.phone_android_outlined,
                value: enquiry.motherPhoneNumber!,
                label: "Mother's Phone",
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(value, style: TextStyle(color: cs.onSurface)),
      subtitle: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
      dense: true,
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Map<String, dynamic> details,
  }) {
    final cs = Theme.of(context).colorScheme;

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
      elevation: 0,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.tertiary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            Divider(height: 20, thickness: 0.5, color: cs.outlineVariant),
            ...validDetails.map((entry) {
              Widget valueWidget;
              if (entry.value is Map) {
                final userData = entry.value as Map<String, dynamic>;
                final name = userData['full_name'] ?? 'N/A';
                final role = userData['role'] ?? '';
                valueWidget = Text(
                  '$name ${role.isNotEmpty ? '($role)' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                );
              } else {
                valueWidget = Text(
                  entry.value?.toString() ?? 'N/A',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: cs.onSurface,
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
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
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

  Color _getTemperatureColor(BuildContext context, String? temp, bool isText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (temp?.toLowerCase()) {
      case 'hot':
        return isText
            ? (isDark ? Colors.red.shade200 : Colors.red.shade700)
            : (isDark ? Colors.red : Colors.red);
      case 'warm':
        return isText
            ? (isDark ? Colors.orange.shade200 : Colors.orange.shade800)
            : (isDark ? Colors.orange : Colors.orange);
      case 'cold':
        return isText
            ? (isDark ? Colors.blue.shade200 : Colors.blue.shade700)
            : (isDark ? Colors.blue : Colors.blue);
      default:
        return isText
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }
}
