import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// --- DATA MODELS ---

// Model for the chart data
class _ChartData {
  _ChartData(this.day, this.calls);
  final String day;
  final int calls;
}

// --- DASHBOARD WIDGET ---

class TelecallerDashboard extends StatefulWidget {
  const TelecallerDashboard({super.key});

  @override
  State<TelecallerDashboard> createState() => _TelecallerDashboardState();
}

class _TelecallerDashboardState extends State<TelecallerDashboard> {
  String _selectedFilter = 'Open';

  // Data for the Syncfusion chart
  final List<_ChartData> _chartDataSource = [
    _ChartData('Mon', 35),
    _ChartData('Tue', 42),
    _ChartData('Wed', 28),
    _ChartData('Thu', 55),
    _ChartData('Fri', 48),
    _ChartData('Sat', 62),
  ];

  // Method to show the Add Enquiry Follow-up Form
  void _showAddFollowUpForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return const AddFollowUpSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telecalling Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () {}),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Analytics Chart ---
            const Text(
              "This Week's Call Activity",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAnalyticsChart(),
            const SizedBox(height: 24),

            // --- Filter and List Section ---
            const Text(
              'Assigned Leads',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildFilterChips(),
            const SizedBox(height: 16),
            _buildLeadsList(),
          ],
        ),
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
            onTap: () => context.pop(),
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
            onTap: () => context.go('/login'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChart() {
    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        primaryXAxis: const CategoryAxis(),
        primaryYAxis: const NumericAxis(isVisible: false),
        plotAreaBorderWidth: 0,
        series: <CartesianSeries>[
          SplineAreaSeries<_ChartData, String>(
            dataSource: _chartDataSource,
            xValueMapper: (_ChartData data, _) => data.day,
            yValueMapper: (_ChartData data, _) => data.calls,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.2),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderWidth: 2,
            borderColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Open', 'Follow-up', 'No Answer', 'Converted'];
    return Wrap(
      spacing: 8.0,
      children: filters.map((filter) {
        return FilterChip(
          label: Text(filter),
          selected: _selectedFilter == filter,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedFilter = filter;
              });
            }
          },
          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
          checkmarkColor: Theme.of(context).primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildLeadsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8, // Placeholder
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            title: Text(
              'Riya Gupta #${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Status: $_selectedFilter',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () {
                    /* Launch dialer */
                  },
                  color: Colors.green,
                ),
                TextButton(
                  onPressed: () => _showAddFollowUpForm(context),
                  child: const Text('Follow-up'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- NEW: ADD FOLLOW-UP FORM WIDGET ---

class AddFollowUpSheet extends StatefulWidget {
  const AddFollowUpSheet({super.key});

  @override
  State<AddFollowUpSheet> createState() => _AddFollowUpSheetState();
}

class _AddFollowUpSheetState extends State<AddFollowUpSheet> {
  final _formKey = GlobalKey<FormState>();

  // Form state variables
  String? _standard;
  String? _board;
  final Set<String> _selectedExams = {};
  bool? _admissionConfirmed;
  final _feedbackController = TextEditingController();

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final followUpData = {
        'student_name': 'Riya Gupta', // This would be passed into the widget
        'standard': _standard,
        'board': _board,
        'exams': _selectedExams.toList(),
        'admission_confirmed': _admissionConfirmed,
        'feedback': _feedbackController.text,
        'date': DateFormat.yMd().format(DateTime.now()),
      };

      // TODO: Send data to the backend
      print('Follow-up Submitted: $followUpData');

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow-up saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    'Enquiry Follow-up',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              // Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoTile('Student Name', 'Riya Gupta'),
                      _buildInfoTile('Mobile No.', '9876543210'),
                      _buildSectionTitle('Academic Details'),
                      _buildRadioGroup(
                        'Standard',
                        ['11th', '12th'],
                        _standard,
                        (val) => setState(() => _standard = val),
                      ),
                      _buildRadioGroup(
                        'Board',
                        ['SSC', 'CBSE'],
                        _board,
                        (val) => setState(() => _board = val),
                      ),
                      _buildCheckboxGroup('Exam', [
                        'JEE',
                        'NEET',
                        'MHT-CET',
                      ], _selectedExams),
                      _buildSectionTitle('Admission Status'),
                      _buildRadioGroup(
                        'Admission Confirmed',
                        ['Yes', 'No'],
                        _admissionConfirmed == null
                            ? null
                            : (_admissionConfirmed! ? 'Yes' : 'No'),
                        (val) => setState(
                          () => _admissionConfirmed = (val == 'Yes'),
                        ),
                      ),
                      _buildTextField(
                        _feedbackController,
                        'Feedback / Remarks',
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save Follow-up'),
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

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.grey)),
      subtitle: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
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
        maxLines: 3,
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildRadioGroup(
    String title,
    List<String> options,
    String? groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        Row(
          children: options
              .map(
                (option) => Expanded(
                  child: RadioListTile<String>(
                    title: Text(option),
                    value: option,
                    groupValue: groupValue,
                    onChanged: onChanged,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCheckboxGroup(
    String title,
    List<String> options,
    Set<String> selectedValues,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        Wrap(
          spacing: 8.0,
          children: options
              .map(
                (option) => FilterChip(
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
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
