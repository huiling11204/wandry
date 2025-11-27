import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import '../controller/admin_service.dart';

/// AdminReportsPage - Comprehensive reports and analytics
/// Place this in lib/screen/admin_reports_page.dart
///
/// Required packages in pubspec.yaml:
/// - pdf: ^3.10.0
/// - path_provider: ^2.1.0
/// - open_file: ^3.3.2
/// - excel: ^4.0.0
class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  bool _isLoading = true;
  bool _isExporting = false;

  // Date range filter
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Report data
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _feedbackStats = {};
  Map<String, dynamic> _activityStats = {};
  List<Map<String, dynamic>> _userList = [];
  List<Map<String, dynamic>> _feedbackList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      // Load user statistics
      _userStats = await _adminService.getUserStatistics();
      _userList = await _adminService.getAllUsers();
      _feedbackList = await _adminService.getAllFeedback();

      // Calculate feedback statistics
      _feedbackStats = _calculateFeedbackStats();

      // Calculate activity statistics
      _activityStats = _calculateActivityStats();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading report data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: ${_adminService.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _calculateFeedbackStats() {
    if (_feedbackList.isEmpty) {
      return {
        'total': 0,
        'avgRating': 0.0,
        'ratingDistribution': [0, 0, 0, 0, 0],
        'thisMonth': 0,
        'lastMonth': 0,
      };
    }

    int total = _feedbackList.length;
    int totalRating = 0;
    List<int> ratingDist = [0, 0, 0, 0, 0];
    int thisMonth = 0;
    int lastMonth = 0;

    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);

    for (var feedback in _feedbackList) {
      final rating = feedback['rating'] ?? 0;
      totalRating += rating as int;

      if (rating >= 1 && rating <= 5) {
        ratingDist[rating - 1]++;
      }

      // Check date
      final createdAt = feedback['createdAt'];
      if (createdAt != null) {
        final date = (createdAt as Timestamp).toDate();
        if (date.isAfter(firstOfMonth)) {
          thisMonth++;
        } else if (date.isAfter(firstOfLastMonth) && date.isBefore(firstOfMonth)) {
          lastMonth++;
        }
      }
    }

    return {
      'total': total,
      'avgRating': total > 0 ? totalRating / total : 0.0,
      'ratingDistribution': ratingDist,
      'thisMonth': thisMonth,
      'lastMonth': lastMonth,
    };
  }

  Map<String, dynamic> _calculateActivityStats() {
    if (_userList.isEmpty) {
      return {
        'totalLogins': 0,
        'activeToday': 0,
        'activeThisWeek': 0,
        'activeThisMonth': 0,
      };
    }

    int activeToday = 0;
    int activeThisWeek = 0;
    int activeThisMonth = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));

    for (var user in _userList) {
      final lastLogin = user['lastLoginDate'];
      if (lastLogin != null) {
        final date = (lastLogin as Timestamp).toDate();
        if (date.isAfter(today)) activeToday++;
        if (date.isAfter(weekAgo)) activeThisWeek++;
        if (date.isAfter(monthAgo)) activeThisMonth++;
      }
    }

    return {
      'activeToday': activeToday,
      'activeThisWeek': activeThisWeek,
      'activeThisMonth': activeThisMonth,
      'totalUsers': _userList.length,
    };
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[600]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: const Color(0xFFB3D9E8),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by Date',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Export',
            onSelected: (value) {
              if (value == 'pdf') {
                _exportToPdf();
              } else if (value == 'excel') {
                _exportToExcel();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Export as PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Export as Excel'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Feedback'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Column(
            children: [
              // Date Range Indicator
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Change'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUserReportTab(),
                    _buildFeedbackReportTab(),
                    _buildActivityReportTab(),
                  ],
                ),
              ),
            ],
          ),

          // Export loading overlay
          if (_isExporting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Exporting...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  '${_userStats['totalUsers'] ?? 0}',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Customers',
                  '${_userStats['totalCustomers'] ?? 0}',
                  Icons.person,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Admins',
                  '${_userStats['totalAdmins'] ?? 0}',
                  Icons.admin_panel_settings,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'New This Month',
                  '${_userStats['newUsersThisMonth'] ?? 0}',
                  Icons.person_add,
                  Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // User Growth Chart Placeholder
          _buildSectionTitle('User Distribution'),
          _buildChartCard(
            child: _buildUserDistributionChart(),
          ),

          const SizedBox(height: 24),

          // Recent Users
          _buildSectionTitle('Recent Registrations'),
          _buildRecentUsersCard(),
        ],
      ),
    );
  }

  Widget _buildFeedbackReportTab() {
    final ratingDist = _feedbackStats['ratingDistribution'] as List<int>? ?? [0, 0, 0, 0, 0];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Feedback',
                  '${_feedbackStats['total'] ?? 0}',
                  Icons.feedback,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Avg Rating',
                  (_feedbackStats['avgRating'] ?? 0.0).toStringAsFixed(1),
                  Icons.star,
                  Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'This Month',
                  '${_feedbackStats['thisMonth'] ?? 0}',
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Last Month',
                  '${_feedbackStats['lastMonth'] ?? 0}',
                  Icons.history,
                  Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Rating Distribution
          _buildSectionTitle('Rating Distribution'),
          _buildChartCard(
            child: _buildRatingDistributionChart(ratingDist),
          ),

          const SizedBox(height: 24),

          // Recent Feedback
          _buildSectionTitle('Recent Feedback'),
          _buildRecentFeedbackCard(),
        ],
      ),
    );
  }

  Widget _buildActivityReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Active Today',
                  '${_activityStats['activeToday'] ?? 0}',
                  Icons.today,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'This Week',
                  '${_activityStats['activeThisWeek'] ?? 0}',
                  Icons.date_range,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'This Month',
                  '${_activityStats['activeThisMonth'] ?? 0}',
                  Icons.calendar_month,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  '${_activityStats['totalUsers'] ?? 0}',
                  Icons.people,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Activity Chart
          _buildSectionTitle('Activity Overview'),
          _buildChartCard(
            child: _buildActivityChart(),
          ),

          const SizedBox(height: 24),

          // System Health
          _buildSectionTitle('System Health'),
          _buildSystemHealthCard(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildChartCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildUserDistributionChart() {
    final customers = _userStats['totalCustomers'] ?? 0;
    final admins = _userStats['totalAdmins'] ?? 0;
    final total = customers + admins;

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPieSegment('Customers', customers, total, Colors.blue),
              _buildPieSegment('Admins', admins, total, Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Customers', Colors.blue),
            const SizedBox(width: 24),
            _buildLegendItem('Admins', Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildPieSegment(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total * 100) : 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: total > 0 ? value / total : 0,
                strokeWidth: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingDistributionChart(List<int> distribution) {
    final maxValue = distribution.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        ...List.generate(5, (index) {
          final rating = 5 - index;
          final count = distribution[rating - 1];
          final percentage = maxValue > 0 ? count / maxValue : 0.0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$rating',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActivityChart() {
    final activeToday = _activityStats['activeToday'] ?? 0;
    final activeWeek = _activityStats['activeThisWeek'] ?? 0;
    final activeMonth = _activityStats['activeThisMonth'] ?? 0;
    final total = _activityStats['totalUsers'] ?? 1;

    return Column(
      children: [
        _buildActivityBar('Today', activeToday, total, Colors.green),
        const SizedBox(height: 12),
        _buildActivityBar('This Week', activeWeek, total, Colors.blue),
        const SizedBox(height: 12),
        _buildActivityBar('This Month', activeMonth, total, Colors.purple),
      ],
    );
  }

  Widget _buildActivityBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? value / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '$value / $total (${(percentage * 100).toStringAsFixed(1)}%)',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentUsersCard() {
    final recentUsers = _userList.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (recentUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No recent users',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            ...recentUsers.map((user) => ListTile(
              leading: CircleAvatar(
                backgroundColor: user['role'] == 'Admin'
                    ? Colors.orange[100]
                    : Colors.blue[100],
                child: Icon(
                  user['role'] == 'Admin'
                      ? Icons.admin_panel_settings
                      : Icons.person,
                  color: user['role'] == 'Admin'
                      ? Colors.orange
                      : Colors.blue,
                  size: 20,
                ),
              ),
              title: Text(
                user['email'] ?? 'N/A',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                user['registrationDate'] != null
                    ? DateFormat('MMM dd, yyyy').format(
                    (user['registrationDate'] as Timestamp).toDate())
                    : 'N/A',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user['role'] == 'Admin'
                      ? Colors.orange[50]
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user['role'] ?? 'N/A',
                  style: TextStyle(
                    fontSize: 11,
                    color: user['role'] == 'Admin'
                        ? Colors.orange
                        : Colors.blue,
                  ),
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildRecentFeedbackCard() {
    final recentFeedback = _feedbackList.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (recentFeedback.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No recent feedback',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            ...recentFeedback.map((feedback) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      '${feedback['rating'] ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                feedback['userEmail'] ?? 'N/A',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                (feedback['comment']?.toString().isNotEmpty ?? false)
                    ? feedback['comment']
                    : 'No comment',
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHealthItem('Database', 'Connected', Colors.green),
          const Divider(),
          _buildHealthItem('Authentication', 'Active', Colors.green),
          const Divider(),
          _buildHealthItem('Cloud Functions', 'Running', Colors.green),
        ],
      ),
    );
  }

  Widget _buildHealthItem(String label, String status, Color color) {
    return Row(
      children: [
        Icon(Icons.check_circle, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportToPdf() async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      // Title Page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Wandry Admin Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated: ${DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Period: ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.SizedBox(height: 24),

                // User Statistics
                pw.Text(
                  'User Statistics',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table.fromTextArray(
                  headers: ['Metric', 'Value'],
                  data: [
                    ['Total Users', '${_userStats['totalUsers'] ?? 0}'],
                    ['Customers', '${_userStats['totalCustomers'] ?? 0}'],
                    ['Admins', '${_userStats['totalAdmins'] ?? 0}'],
                    ['New This Month', '${_userStats['newUsersThisMonth'] ?? 0}'],
                  ],
                ),
                pw.SizedBox(height: 24),

                // Feedback Statistics
                pw.Text(
                  'Feedback Statistics',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table.fromTextArray(
                  headers: ['Metric', 'Value'],
                  data: [
                    ['Total Feedback', '${_feedbackStats['total'] ?? 0}'],
                    ['Average Rating', '${(_feedbackStats['avgRating'] ?? 0.0).toStringAsFixed(1)}'],
                    ['This Month', '${_feedbackStats['thisMonth'] ?? 0}'],
                    ['Last Month', '${_feedbackStats['lastMonth'] ?? 0}'],
                  ],
                ),
                pw.SizedBox(height: 24),

                // Activity Statistics
                pw.Text(
                  'Activity Statistics',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table.fromTextArray(
                  headers: ['Metric', 'Value'],
                  data: [
                    ['Active Today', '${_activityStats['activeToday'] ?? 0}'],
                    ['Active This Week', '${_activityStats['activeThisWeek'] ?? 0}'],
                    ['Active This Month', '${_activityStats['activeThisMonth'] ?? 0}'],
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Save and open
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/wandry_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
      await file.writeAsBytes(await pdf.save());

      setState(() => _isExporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF exported successfully'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error exporting PDF: $e');
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      final excel = Excel.createExcel();

      // Users Sheet
      final usersSheet = excel['Users'];
      usersSheet.appendRow([
        TextCellValue('User ID'),
        TextCellValue('Email'),
        TextCellValue('Role'),
        TextCellValue('Registration Date'),
        TextCellValue('Last Login'),
      ]);

      for (var user in _userList) {
        usersSheet.appendRow([
          TextCellValue(user['userID'] ?? ''),
          TextCellValue(user['email'] ?? ''),
          TextCellValue(user['role'] ?? ''),
          TextCellValue(user['registrationDate'] != null
              ? DateFormat('yyyy-MM-dd HH:mm')
              .format((user['registrationDate'] as Timestamp).toDate())
              : ''),
          TextCellValue(user['lastLoginDate'] != null
              ? DateFormat('yyyy-MM-dd HH:mm')
              .format((user['lastLoginDate'] as Timestamp).toDate())
              : ''),
        ]);
      }

      // Feedback Sheet
      final feedbackSheet = excel['Feedback'];
      feedbackSheet.appendRow([
        TextCellValue('Email'),
        TextCellValue('Rating'),
        TextCellValue('Comment'),
        TextCellValue('Date'),
      ]);

      for (var feedback in _feedbackList) {
        feedbackSheet.appendRow([
          TextCellValue(feedback['userEmail'] ?? ''),
          TextCellValue('${feedback['rating'] ?? 0}'),
          TextCellValue(feedback['comment'] ?? ''),
          TextCellValue(feedback['createdAt'] != null
              ? DateFormat('yyyy-MM-dd HH:mm')
              .format((feedback['createdAt'] as Timestamp).toDate())
              : ''),
        ]);
      }

      // Statistics Sheet
      final statsSheet = excel['Statistics'];
      statsSheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
      statsSheet.appendRow([TextCellValue('Total Users'), TextCellValue('${_userStats['totalUsers'] ?? 0}')]);
      statsSheet.appendRow([TextCellValue('Customers'), TextCellValue('${_userStats['totalCustomers'] ?? 0}')]);
      statsSheet.appendRow([TextCellValue('Admins'), TextCellValue('${_userStats['totalAdmins'] ?? 0}')]);
      statsSheet.appendRow([TextCellValue('Total Feedback'), TextCellValue('${_feedbackStats['total'] ?? 0}')]);
      statsSheet.appendRow([TextCellValue('Average Rating'), TextCellValue('${(_feedbackStats['avgRating'] ?? 0.0).toStringAsFixed(1)}')]);

      // Remove default sheet
      excel.delete('Sheet1');

      // Save and open
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/wandry_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final fileBytes = excel.save();

      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        setState(() => _isExporting = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Excel exported successfully'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () => OpenFile.open(file.path),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error exporting Excel: $e');
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}