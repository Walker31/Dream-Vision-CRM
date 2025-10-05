import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart'; // Import for date formatting

// --- DATA MODELS ---

// Model for the chart data
class _ChartData {
  _ChartData(this.status, this.value, this.color);
  final String status;
  final double value;
  final Color color;
}

// Model for an enquiry
class Enquiry {
  final String id;
  final String name;
  final String status;
  final DateTime lastVisit;
  final int visitCount;

  Enquiry({
    required this.id,
    required this.name,
    required this.status,
    required this.lastVisit,
    required this.visitCount,
  });
}


// --- DASHBOARD WIDGET ---

class CounsellorDashboard extends StatefulWidget {
  const CounsellorDashboard({super.key});

  @override
  State<CounsellorDashboard> createState() => _CounsellorDashboardState();
}

class _CounsellorDashboardState extends State<CounsellorDashboard> {
  Logger logger = Logger();
  // Mock data for the list of enquiries
  final List<Enquiry> _enquiries = [
    Enquiry(id: '1', name: 'Aarav Sharma', status: 'Interested', lastVisit: DateTime.now(), visitCount: 2),
    Enquiry(id: '2', name: 'Priya Patel', status: 'Converted', lastVisit: DateTime.now().subtract(const Duration(days: 2)), visitCount: 3),
    Enquiry(id: '3', name: 'Rohan Mehta', status: 'Needs Follow-up', lastVisit: DateTime.now().subtract(const Duration(days: 5)), visitCount: 1),
    Enquiry(id: '4', name: 'Sneha Verma', status: 'Interested', lastVisit: DateTime.now().subtract(const Duration(days: 1)), visitCount: 1),
    Enquiry(id: '5', name: 'Vikram Singh', status: 'Closed', lastVisit: DateTime.now().subtract(const Duration(days: 10)), visitCount: 2),
  ];

  // Data for the Syncfusion chart
  final List<_ChartData> _chartDataSource = [
    _ChartData('Converted', 40, Colors.green.shade500),
    _ChartData('Interested', 30, Colors.blue.shade500),
    _ChartData('Follow-up', 20, Colors.orange.shade500),
    _ChartData('Closed', 10, Colors.grey.shade500),
  ];

  // Helper to get a color based on enquiry status for the list chip
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Interested':
        return Colors.blue.shade600;
      case 'Converted':
        return Colors.green.shade600;
      case 'Needs Follow-up':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // --- NEW: Method to show the Add Enquiry Form ---
  void _showAddEnquiryForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important for scrollable content
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return const AddEnquirySheet(); // Use the new form widget
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Counsellor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {},
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Analytics Section ---
            const Text(
              "This Week's Analytics",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAnalyticsCharts(),
            const SizedBox(height: 24),

            // --- Enquiries List Section ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Enquiries",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(onPressed: () {}, child: const Text('View All'))
              ],
            ),
            const SizedBox(height: 8),
            _buildEnquiryList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEnquiryForm(context), // Updated onPressed
        label: const Text('New Enquiry'),
        icon: const Icon(Icons.add),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const SizedBox(height: 50),
          ListTile(
            title: const Text('Dashboard'),
            leading: const Icon(Icons.dashboard_outlined),
            onTap: () => context.pop(), // Close drawer
          ),
          ListTile(
            title: const Text('Manage Users'),
            leading: const Icon(Icons.group_outlined),
            onTap: () => context.push('/users'),
          ),
          ListTile(
              title: const Text('Counsellor Dashboard'),
              leading: const Icon(Icons.people),
              onTap: () {
                context.push('/councellor');
              },
            ),
            ListTile(
              title: const Text('Telecaller Dashboard'),
              leading: const Icon(Icons.phone),
              onTap: () {
                context.push('/telecaller');
              },
            ),
          const Spacer(),
          ListTile(
            title: const Text('Logout'),
            leading: const Icon(Icons.logout),
            onTap: () {
              // Proper logout logic should be handled by a provider
              context.go('/login');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCharts() {
    return Row(
      children: [
        // Syncfusion Doughnut Chart
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 160,
            child: SfCircularChart(
              series: <CircularSeries<_ChartData, String>>[
                DoughnutSeries<_ChartData, String>(
                  dataSource: _chartDataSource,
                  xValueMapper: (_ChartData data, _) => data.status,
                  yValueMapper: (_ChartData data, _) => data.value,
                  pointColorMapper: (_ChartData data, _) => data.color,
                  innerRadius: '60%',
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    labelPosition: ChartDataLabelPosition.inside,
                    labelIntersectAction: LabelIntersectAction.hide,
                  ),
                  dataLabelMapper: (_ChartData data, _) => '${data.value.toInt()}%',
                )
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend for Chart
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: _chartDataSource.map((data) {
              return _buildLegendItem(data.color, data.status);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildEnquiryList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _enquiries.length,
      itemBuilder: (context, index) {
        final enquiry = _enquiries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            title: Text(enquiry.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Last Visit: ${DateFormat.yMd().format(enquiry.lastVisit)}', style: TextStyle(color: Colors.grey[600])),
                Text('Total Visits: ${enquiry.visitCount}', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            trailing: Chip(
              label: Text(enquiry.status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              backgroundColor: _getStatusColor(enquiry.status),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            ),
            onTap: () { /* Navigate to enquiry details */ },
          ),
        );
      },
    );
  }
}


// --- NEW: ADD ENQUIRY FORM WIDGET ---

class AddEnquirySheet extends StatefulWidget {
  const AddEnquirySheet({super.key});

  @override
  State<AddEnquirySheet> createState() => _AddEnquirySheetState();
}

class _AddEnquirySheetState extends State<AddEnquirySheet> {
  final _formKey = GlobalKey<FormState>();

  Logger logger = Logger();
  // Form state variables
  DateTime? _selectedDate = DateTime.now();
  DateTime? _selectedDob;
  String? _enquiringFor;
  final Set<String> _selectedExams = {};
  final Set<String> _referredBy = {};
  String? _academicBoard;
  String? _officeUseStatus;

  // Controllers for text fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  // ... add controllers for all other text fields ...

  Future<void> _pickDate(BuildContext context, {required bool isDob}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isDob) {
          _selectedDob = picked;
        } else {
          _selectedDate = picked;
        }
      });
    }
  }
  
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Form is valid, collect all data
      final enquiryData = {
        'date': DateFormat.yMd().format(_selectedDate!),
        'dob': _selectedDob != null ? DateFormat.yMd().format(_selectedDob!) : '',
        'student_name': '${_firstNameController.text} ${_lastNameController.text}',
        'enquiring_for_standard': _enquiringFor,
        'exams': _selectedExams.toList(),
        // ... collect data from all controllers and state variables ...
        'referred_by': _referredBy.toList(),
        'academic_board': _academicBoard,
        'office_use_status': _officeUseStatus,
        'remark': '...' // from remark controller
      };

      // TODO: Send data to the backend via a service
      logger.d('Form Submitted: $enquiryData');

      Navigator.of(context).pop(); // Close the bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enquiry submitted successfully!'), backgroundColor: Colors.green),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // Allows the sheet to take up 90% of the screen height
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New Enquiry Form', style: Theme.of(context).textTheme.headlineSmall),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              const Divider(),
              // Scrollable Form Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date and DOB
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField('Date', _selectedDate, () => _pickDate(context, isDob: false)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateField('DOB', _selectedDob, () => _pickDate(context, isDob: true)),
                          ),
                        ],
                      ),
                      _buildTextField(_firstNameController, 'First Name'),
                      _buildTextField(_lastNameController, 'Last Name'),
                      _buildSectionTitle('Enquiring for Standard'),
                      _buildRadioGroup(['11th', '12th'], _enquiringFor, (val) => setState(() => _enquiringFor = val)),
                      _buildSectionTitle('Exam'),
                      _buildCheckboxGroup(['JEE', 'NEET', 'MHT-CET'], _selectedExams),
                      _buildSectionTitle('Referred by'),
                      _buildCheckboxGroup(['Friends/Family', 'Internet', 'Hoarding', 'Pamphlets', 'Newspaper', 'Call'], _referredBy),
                      // ... Add all other fields from the form image here ...
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit Enquiry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FORM HELPER WIDGETS ---
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          child: Text(
            date != null ? DateFormat.yMd().format(date) : 'Select a date',
          ),
        ),
      ),
    );
  }

  Widget _buildRadioGroup(List<String> options, String? groupValue, ValueChanged<String?> onChanged) {
    return Column(
      children: options.map((option) => RadioListTile<String>(
        title: Text(option),
        value: option,
        groupValue: groupValue,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      )).toList(),
    );
  }

  Widget _buildCheckboxGroup(List<String> options, Set<String> selectedValues) {
    return Wrap(
      spacing: 8.0,
      children: options.map((option) => FilterChip(
        label: Text(option),
        selected: selectedValues.contains(option),
        onSelected: (selected) {
          setState(() {
            if (selected) {
              selectedValues.add(option);
            } else {
              selectedValues.remove(option);
            }
          });
        },
      )).toList(),
    );
  }
}

