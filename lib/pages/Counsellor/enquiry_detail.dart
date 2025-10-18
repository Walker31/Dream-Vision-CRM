import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';

class EnquiryDetailPage extends StatefulWidget {
  final int enquiryId;

  const EnquiryDetailPage({super.key, required this.enquiryId});

  @override
  State<EnquiryDetailPage> createState() => _EnquiryDetailPageState();
}

class _EnquiryDetailPageState extends State<EnquiryDetailPage> {
  // Assume EnquiryService is available, e.g., via a provider or as a singleton.
  // For simplicity, it's instantiated here.
  final EnquiryService _enquiryService = EnquiryService();
  late Future<Enquiry> _enquiryFuture;

  @override
  void initState() {
    super.initState();
    // Start fetching the data when the widget is first created.
    _enquiryFuture = _fetchEnquiryData();
  }

  Future<Enquiry> _fetchEnquiryData() async {
    final jsonData = await _enquiryService.getEnquiryById(widget.enquiryId);
    return Enquiry.fromJson(jsonData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButtonIos(),
        title: const Text('Enquiry Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<Enquiry>(
        future: _enquiryFuture,
        builder: (context, snapshot) {
          // 1. WHILE LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. IF ERROR
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load enquiry: ${snapshot.error}'),
              ),
            );
          }
          // 3. IF SUCCESS
          if (snapshot.hasData) {
            final enquiry = snapshot.data!;
            return _buildDetailsView(context, enquiry);
          }
          // 4. IF NO DATA (Should ideally not be reached if API is consistent)
          return const Center(child: Text('No enquiry data found.'));
        },
      ),
    );
  }

  /// Builds the main content view once the enquiry data is available.
  Widget _buildDetailsView(BuildContext context, Enquiry enquiry) {
    return SingleChildScrollView(
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
                'School': enquiry.school,
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
                'Created At': enquiry.createdAt.split('T').first,
              },
            ),
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
                ).withValues(alpha: 0.1),
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
            if (enquiry.email != null)
              _buildContactTile(
                icon: Icons.email_outlined,
                value: enquiry.email!,
                label: 'Email',
              ),
            if (enquiry.fatherPhoneNumber != null)
              _buildContactTile(
                icon: Icons.phone_android_outlined,
                value: enquiry.fatherPhoneNumber!,
                label: "Father's Phone",
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
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Map<String, String?> details,
  }) {
    final validDetails = details.entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
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
                Icon(icon, color: Colors.indigo.shade400),
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
            const Divider(height: 20),
            ...validDetails.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${entry.key}:',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.value!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
        return Colors.grey.shade700;
    }
  }
}
