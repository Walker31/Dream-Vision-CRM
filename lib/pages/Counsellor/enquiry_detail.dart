import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../Telecaller/follow_up_sheet.dart';

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

  void _goToEditPage(BuildContext context, Enquiry enquiry) async {
    // We expect a bool (true) if the page was saved.
    final bool? result = await context.push<bool>(
      '/add-enquiry', // This MUST match your GoRouter path for AddEnquiryPage
      extra: enquiry, // Pass the full enquiry object
    );

    // If the edit page returns true, it means we saved, so refresh.
    if (result == true && mounted) {
      _refreshEnquiryData();
    }
  }

  void _showAddFollowUpSheet(BuildContext context, Enquiry enquiry) async {
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

  Future<void> _showUserSelectionDialog(
    BuildContext context,
    String role,
    int enquiryId,
  ) async {
    final selectedUserId = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return _UserSelectionDialog(
          role: role,
          enquiryService: _enquiryService,
        );
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
          fullName =
              '${enquiry.firstName} ${enquiry.lastName ?? ''}' // CHANGED: Assigned value here
                  .trim();
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
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      label: const Text('Edit Enquiry'),
                      icon: Icon(Icons.edit_outlined),
                      heroTag: 'enquiryEdit',
                      tooltip: 'Edit Enquiry',
                      onPressed: () => _goToEditPage(context, enquiry),
                    ),
                    const SizedBox(height: 16),
                    // New History FAB
                    FloatingActionButton(
                      heroTag: 'historyFab', // Added unique HeroTag
                      onPressed: () {
                        context.push(
                          '/follow-ups/${enquiry.id}',
                          extra: fullName,
                        );
                      },
                      tooltip: 'View Follow-up History',
                      child: const Icon(Icons.history_outlined),
                    ),
                    const SizedBox(height: 16),
                    // Existing Add Follow-up FAB
                    FloatingActionButton.extended(
                      heroTag: 'addFollowUpFab', // Added unique HeroTag
                      onPressed: () => _showAddFollowUpSheet(context, enquiry),
                      icon: const Icon(Icons.add_comment_outlined),
                      label: const Text('Add Follow-up'),
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
            const SizedBox(height: 80),
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

class _UserSelectionDialog extends StatefulWidget {
  final String role;
  final EnquiryService enquiryService;

  const _UserSelectionDialog({
    required this.role,
    required this.enquiryService,
  });

  @override
  State<_UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _debounce;
  Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final fetchedUsers = await widget.enquiryService.getAssignableUsers(
        role: widget.role,
        query: query,
      );
      if (mounted) {
        setState(() {
          _users = fetchedUsers;
          _filteredUsers = fetchedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching users: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredUsers = _users.where((user) {
          final name = (user['full_name'] ?? user['username'] ?? '')
              .toLowerCase();
          return name.contains(query);
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign ${widget.role}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 16),
            _buildUserList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_filteredUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Text(
          _searchController.text.isEmpty
              ? 'No ${widget.role}s found.'
              : 'No ${widget.role}s found matching "${_searchController.text}".',
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final details = _filteredUsers[index];
          final user = details['user'];
          logger.d(user);
          final userName =
              user['full_name'] ?? user['username'] ?? 'Unnamed User';
          final userId = details['id'];

          return ListTile(
            title: Text(userName),
            onTap: () {
              Navigator.of(context).pop(userId);
            },
          );
        },
      ),
    );
  }
}
