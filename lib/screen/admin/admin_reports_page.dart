import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:wandry/controller/admin_service.dart';
import 'package:wandry/controller/theme_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wandry/widget/sweet_alert_dialog.dart';

/// Comprehensive reports and analytics


// ============================================================
// REPORT TYPE ENUM
// ============================================================
enum ReportType {
  users('User Report', Icons.people, Colors.blue),
  feedback('Feedback Report', Icons.feedback, Colors.purple),
  activity('Activity Report', Icons.analytics, Colors.green),
  combined('Combined Report', Icons.summarize, Colors.orange);

  final String label;
  final IconData icon;
  final Color color;

  const ReportType(this.label, this.icon, this.color);
}

// ============================================================
// REPORT STATUS ENUM
// ============================================================
enum ReportStatus {
  generating('Generating'),
  completed('Completed'),
  failed('Failed');

  final String label;
  const ReportStatus(this.label);
}

// ============================================================
// GENERATED REPORT MODEL - MATCHES DATA DICTIONARY
// ============================================================
class GeneratedReport {
  final String reportLogID;           // Primary Key
  final String adminProfileID;        // Foreign Key to Admin Profile
  final String reportTypeGenerated;   // Type of report
  final DateTime startDateParam;      // Start date parameter
  final DateTime endDateParam;        // End date parameter
  final DateTime generationTimestamp; // When report was generated
  final String outputFormat;          // 'pdf' or 'excel'
  final String status;                // 'Generating', 'Completed', 'Failed'
  final String filePath;              // Local file path
  final int fileSize;                 // File size in bytes

  GeneratedReport({
    required this.reportLogID,
    required this.adminProfileID,
    required this.reportTypeGenerated,
    required this.startDateParam,
    required this.endDateParam,
    required this.generationTimestamp,
    required this.outputFormat,
    required this.status,
    required this.filePath,
    required this.fileSize,
  });

  /// Convert to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'reportLogID': reportLogID,
      'adminProfileID': adminProfileID,
      'reportTypeGenerated': reportTypeGenerated,
      'startDateParam': Timestamp.fromDate(startDateParam),
      'endDateParam': Timestamp.fromDate(endDateParam),
      'generationTimestamp': Timestamp.fromDate(generationTimestamp),
      'outputFormat': outputFormat,
      'status': status,
      'filePath': filePath,
      'fileSize': fileSize,
    };
  }

  /// Create from Firestore Map
  factory GeneratedReport.fromMap(Map<String, dynamic> map) {
    return GeneratedReport(
      reportLogID: map['reportLogID'] ?? '',
      adminProfileID: map['adminProfileID'] ?? '',
      reportTypeGenerated: map['reportTypeGenerated'] ?? '',
      startDateParam: (map['startDateParam'] as Timestamp).toDate(),
      endDateParam: (map['endDateParam'] as Timestamp).toDate(),
      generationTimestamp: (map['generationTimestamp'] as Timestamp).toDate(),
      outputFormat: map['outputFormat'] ?? 'pdf',
      status: map['status'] ?? 'Completed',
      filePath: map['filePath'] ?? '',
      fileSize: map['fileSize'] ?? 0,
    );
  }

  /// Helper to get ReportType enum from string
  ReportType get reportType {
    switch (reportTypeGenerated.toLowerCase()) {
      case 'user report':
        return ReportType.users;
      case 'feedback report':
        return ReportType.feedback;
      case 'activity report':
        return ReportType.activity;
      default:
        return ReportType.combined;
    }
  }

  /// Helper to get display name
  String get displayName {
    return '${DateFormat('MMM yyyy').format(startDateParam)} $reportTypeGenerated';
  }
}

// ============================================================
// MAIN REPORTS PAGE
// ============================================================
class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ThemeController _themeController = ThemeController();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isExporting = false;
  String _exportStatus = 'Preparing...';

  // Date range filter
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Report data - FILTERED versions
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _feedbackStats = {};
  Map<String, dynamic> _activityStats = {};
  List<Map<String, dynamic>> _userList = [];
  List<Map<String, dynamic>> _feedbackList = [];

  // Original unfiltered data
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allFeedback = [];

  // Generated reports history
  List<GeneratedReport> _generatedReports = [];

  // Current admin profile ID
  String? _currentAdminProfileID;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeData();
    _themeController.addListener(_onThemeChanged);
  }

  Future<void> _initializeData() async {
    await _getCurrentAdminProfileID();
    await _loadReportData();
    await _loadGeneratedReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  ThemeController get tc => _themeController;

  /// Get the current admin's profile ID
  Future<void> _getCurrentAdminProfileID() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Try to get from adminProfile collection
        final adminQuery = await _firestore
            .collection('adminProfile')
            .where('firebaseUid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (adminQuery.docs.isNotEmpty) {
          _currentAdminProfileID = adminQuery.docs.first.id;
        } else {
          // Fallback to firebase UID
          _currentAdminProfileID = user.uid;
        }
      }
    } catch (e) {
      print('Error getting admin profile ID: $e');
      _currentAdminProfileID = _auth.currentUser?.uid;
    }
  }

  // ============================================================
  // DATA LOADING WITH PROPER FILTERING
  // ============================================================
  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      // Load all data first
      _userStats = await _adminService.getUserStatistics();
      _allUsers = await _adminService.getAllUsers();
      _allFeedback = await _adminService.getAllFeedback();

      // Apply date filter
      _applyDateFilter();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading report data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        SweetAlertDialog.error(
          context: context,
          title: 'Error Loading Reports',
          subtitle: _adminService.getErrorMessage(e),
        );
      }
    }
  }

  /// Apply date filter to all data
  void _applyDateFilter() {
    final startOfDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

    // Filter users by registration date
    _userList = _allUsers.where((user) {
      final regDate = user['registrationDate'];
      if (regDate == null) return false;
      final date = (regDate as Timestamp).toDate();
      return date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          date.isBefore(endOfDay.add(const Duration(seconds: 1)));
    }).toList();

    // Filter feedback by creation date
    _feedbackList = _allFeedback.where((feedback) {
      final createdAt = feedback['createdAt'];
      if (createdAt == null) return false;
      final date = (createdAt as Timestamp).toDate();
      return date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          date.isBefore(endOfDay.add(const Duration(seconds: 1)));
    }).toList();

    // Recalculate statistics based on filtered data
    _userStats = _calculateFilteredUserStats();
    _feedbackStats = _calculateFeedbackStats();
    _activityStats = _calculateActivityStats();

    setState(() {});
  }

  Map<String, dynamic> _calculateFilteredUserStats() {
    int totalCustomers = 0;
    int totalAdmins = 0;

    for (var user in _userList) {
      final role = user['role']?.toString().toLowerCase() ?? '';
      if (role == 'admin') {
        totalAdmins++;
      } else {
        totalCustomers++;
      }
    }

    return {
      'totalUsers': _userList.length,
      'totalCustomers': totalCustomers,
      'totalAdmins': totalAdmins,
      'newUsersThisMonth': _userList.length,
    };
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

    for (var feedback in _feedbackList) {
      final rating = feedback['rating'] ?? 0;
      totalRating += rating as int;

      if (rating >= 1 && rating <= 5) {
        ratingDist[rating - 1]++;
      }
    }

    return {
      'total': total,
      'avgRating': total > 0 ? totalRating / total : 0.0,
      'ratingDistribution': ratingDist,
      'thisMonth': total,
      'lastMonth': 0,
    };
  }

  Map<String, dynamic> _calculateActivityStats() {
    if (_userList.isEmpty && _allUsers.isEmpty) {
      return {
        'totalLogins': 0,
        'activeToday': 0,
        'activeThisWeek': 0,
        'activeThisMonth': 0,
        'totalUsers': 0,
      };
    }

    int activeInPeriod = 0;

    final startOfDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

    for (var user in _allUsers) {
      final lastLogin = user['lastLoginDate'];
      if (lastLogin != null) {
        final date = (lastLogin as Timestamp).toDate();
        if (date.isAfter(startOfDay) && date.isBefore(endOfDay)) {
          activeInPeriod++;
        }
      }
    }

    return {
      'activeInPeriod': activeInPeriod,
      'activeToday': _countActiveUsers(0),
      'activeThisWeek': _countActiveUsers(7),
      'activeThisMonth': _countActiveUsers(30),
      'totalUsers': _allUsers.length,
      'filteredUsers': _userList.length,
    };
  }

  int _countActiveUsers(int daysBack) {
    final cutoff = DateTime.now().subtract(Duration(days: daysBack));
    return _allUsers.where((user) {
      final lastLogin = user['lastLoginDate'];
      if (lastLogin == null) return false;
      return (lastLogin as Timestamp).toDate().isAfter(cutoff);
    }).length;
  }

  // ============================================================
  // GENERATED REPORTS MANAGEMENT - FIRESTORE
  // ============================================================
  Future<void> _loadGeneratedReports() async {
    try {
      final snapshot = await _firestore
          .collection('generated_reports')
          .orderBy('generationTimestamp', descending: true)
          .limit(50)
          .get();

      _generatedReports = snapshot.docs
          .map((doc) => GeneratedReport.fromMap(doc.data()))
          .toList();

      // Clean up missing files
      await _cleanupMissingFiles();

      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading generated reports: $e');
    }
  }

  Future<void> _cleanupMissingFiles() async {
    List<String> toDelete = [];

    for (var report in _generatedReports) {
      if (report.filePath.isNotEmpty) {
        final file = File(report.filePath);
        if (!await file.exists()) {
          toDelete.add(report.reportLogID);
        }
      }
    }

    // Remove from Firestore
    for (var id in toDelete) {
      try {
        await _firestore.collection('generated_reports').doc(id).delete();
      } catch (e) {
        print('Error deleting orphaned report: $e');
      }
    }

    _generatedReports.removeWhere((r) => toDelete.contains(r.reportLogID));
  }

  Future<void> _deleteReport(GeneratedReport report) async {
    final confirm = await SweetAlertDialog.confirm(
      context: context,
      title: 'Delete Report',
      subtitle: 'Are you sure you want to delete "${report.displayName}"?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirm == true) {
      try {
        // Delete file
        if (report.filePath.isNotEmpty) {
          final file = File(report.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }

        // Delete from Firestore
        await _firestore.collection('generated_reports').doc(report.reportLogID).delete();

        // Update local list
        _generatedReports.removeWhere((r) => r.reportLogID == report.reportLogID);
        setState(() {});

        if (mounted) {
          SweetAlertDialog.success(
            context: context,
            title: 'Report Deleted',
            subtitle: 'The report has been deleted successfully.',
          );
        }
      } catch (e) {
        if (mounted) {
          SweetAlertDialog.error(
            context: context,
            title: 'Delete Failed',
            subtitle: 'Failed to delete report: $e',
          );
        }
      }
    }
  }

  // ============================================================
  // DATE PICKER
  // ============================================================
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
      _applyDateFilter();
    }
  }

  // ============================================================
  // REPORT GENERATION DIALOG
  // ============================================================
  Future<void> _showGenerateReportDialog() async {
    ReportType selectedType = ReportType.combined;
    String selectedFormat = 'pdf';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: tc.dialogBackgroundColor,
          title: Text('Generate Report', style: TextStyle(color: tc.textColor)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Type',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: tc.textColor),
                ),
                const SizedBox(height: 8),
                ...ReportType.values.map((type) => RadioListTile<ReportType>(
                  title: Row(
                    children: [
                      Icon(type.icon, color: type.color, size: 20),
                      const SizedBox(width: 8),
                      Text(type.label, style: TextStyle(color: tc.textColor)),
                    ],
                  ),
                  value: type,
                  groupValue: selectedType,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setDialogState(() => selectedType = value!);
                  },
                )),

                const SizedBox(height: 16),
                Divider(color: tc.dividerColor),
                const SizedBox(height: 16),

                Text(
                  'Export Format',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: tc.textColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormatOption(
                        'PDF',
                        Icons.picture_as_pdf,
                        Colors.red,
                        selectedFormat == 'pdf',
                            () => setDialogState(() => selectedFormat = 'pdf'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormatOption(
                        'Excel',
                        Icons.table_chart,
                        Colors.green,
                        selectedFormat == 'excel',
                            () => setDialogState(() => selectedFormat = 'excel'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tc.isDarkMode ? Colors.blue.withOpacity(0.2) : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Data period: ${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: tc.subtitleColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'type': selectedType,
                'format': selectedFormat,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final type = result['type'] as ReportType;
      final format = result['format'] as String;

      if (format == 'pdf') {
        await _exportToPdf(type);
      } else {
        await _exportToExcel(type);
      }
    }
  }

  Widget _buildFormatOption(
      String label,
      IconData icon,
      Color color,
      bool isSelected,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : (tc.isDarkMode ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : tc.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : tc.iconColor, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : tc.subtitleColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Reports',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: tc.appBarForegroundColor,
          ),
        ),
        backgroundColor: tc.appBarColor,
        iconTheme: IconThemeData(color: tc.appBarForegroundColor),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by Date',
          ),
          IconButton(
            icon: const Icon(Icons.add_chart),
            onPressed: _showGenerateReportDialog,
            tooltip: 'Generate Report',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadReportData();
              _loadGeneratedReports();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: tc.isDarkMode ? Colors.blue[400] : Colors.white,
          labelColor: tc.appBarForegroundColor,
          unselectedLabelColor: tc.appBarForegroundColor.withOpacity(0.6),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Feedback'),
            Tab(text: 'Activity'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blue[600]))
          : Stack(
        children: [
          Column(
            children: [
              _buildDateRangeIndicator(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUserReportTab(),
                    _buildFeedbackReportTab(),
                    _buildActivityReportTab(),
                    _buildReportHistoryTab(),
                  ],
                ),
              ),
            ],
          ),
          if (_isExporting) _buildExportingOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateReportDialog,
        backgroundColor: Colors.blue[600],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Generate',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDateRangeIndicator() {
    final days = _endDate.difference(_startDate).inDays + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: tc.cardColor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.calendar_today, size: 16, color: Colors.blue[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  style: TextStyle(
                    color: tc.textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$days days • ${_userList.length} users • ${_feedbackList.length} feedback',
                  style: TextStyle(
                    color: tc.subtitleColor,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _selectDateRange,
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue[600],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, size: 14, color: Colors.blue[600]),
                const SizedBox(width: 4),
                const Text('Change', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Card(
          color: tc.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.blue[600]),
                const SizedBox(height: 20),
                Text(
                  _exportStatus,
                  style: TextStyle(fontSize: 16, color: tc.textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // USER REPORT TAB
  // ============================================================
  Widget _buildUserReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  '${_userStats['totalUsers'] ?? 0}',
                  Icons.people,
                  Colors.blue,
                  subtitle: 'in selected period',
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
                  'All Time Total',
                  '${_allUsers.length}',
                  Icons.groups,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('User Distribution'),
          _buildChartCard(child: _buildUserDistributionChart()),
          const SizedBox(height: 24),
          _buildSectionTitle('Users in Period (${_userList.length})'),
          _buildRecentUsersCard(),
        ],
      ),
    );
  }

  // ============================================================
  // FEEDBACK REPORT TAB
  // ============================================================
  Widget _buildFeedbackReportTab() {
    final ratingDist = _feedbackStats['ratingDistribution'] as List<int>? ?? [0, 0, 0, 0, 0];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Feedback',
                  '${_feedbackStats['total'] ?? 0}',
                  Icons.feedback,
                  Colors.purple,
                  subtitle: 'in selected period',
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
                  'All Time Total',
                  '${_allFeedback.length}',
                  Icons.history,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '5-Star Reviews',
                  '${ratingDist[4]}',
                  Icons.star,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Rating Distribution'),
          _buildChartCard(child: _buildRatingDistributionChart(ratingDist)),
          const SizedBox(height: 24),
          _buildSectionTitle('Feedback in Period (${_feedbackList.length})'),
          _buildRecentFeedbackCard(),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIVITY REPORT TAB
  // ============================================================
  Widget _buildActivityReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  'In Period',
                  '${_activityStats['activeInPeriod'] ?? 0}',
                  Icons.filter_list,
                  Colors.orange,
                  subtitle: 'active users',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Activity Overview'),
          _buildChartCard(child: _buildActivityChart()),
          const SizedBox(height: 24),
          _buildSectionTitle('System Health'),
          _buildSystemHealthCard(),
        ],
      ),
    );
  }

  // ============================================================
  // REPORT HISTORY TAB
  // ============================================================
  Widget _buildReportHistoryTab() {
    return _generatedReports.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: tc.iconColor),
          const SizedBox(height: 16),
          Text(
            'No generated reports yet',
            style: TextStyle(fontSize: 16, color: tc.textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the Generate button to create a report',
            style: TextStyle(fontSize: 14, color: tc.subtitleColor),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showGenerateReportDialog,
            icon: const Icon(Icons.add),
            label: const Text('Generate Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _generatedReports.length,
      itemBuilder: (context, index) {
        final report = _generatedReports[index];
        return _buildReportHistoryItem(report);
      },
    );
  }

  Widget _buildReportHistoryItem(GeneratedReport report) {
    final fileSize = (report.fileSize / 1024).toStringAsFixed(1);
    final isPdf = report.outputFormat.toLowerCase() == 'pdf';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: tc.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPdf
                      ? (tc.isDarkMode ? Colors.red.withOpacity(0.2) : Colors.red[50])
                      : (tc.isDarkMode ? Colors.green.withOpacity(0.2) : Colors.green[50]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.table_chart,
                  color: isPdf ? Colors.red : Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title - Report Type and Date
                    Text(
                      '${DateFormat('MMM yyyy').format(report.startDateParam)} ${report.reportTypeGenerated}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: tc.textColor,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${report.reportTypeGenerated} • $fileSize KB',
                      style: TextStyle(color: tc.subtitleColor, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Period: ${DateFormat('MMM dd').format(report.startDateParam)} - ${DateFormat('MMM dd, yyyy').format(report.endDateParam)}',
                      style: TextStyle(color: tc.subtitleColor, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(report.generationTimestamp)}',
                      style: TextStyle(color: tc.subtitleColor, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: report.status == 'Completed'
                            ? (tc.isDarkMode ? Colors.green.withOpacity(0.2) : Colors.green[50])
                            : report.status == 'Failed'
                            ? (tc.isDarkMode ? Colors.red.withOpacity(0.2) : Colors.red[50])
                            : (tc.isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange[50]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: report.status == 'Completed'
                              ? Colors.green[700]
                              : report.status == 'Failed'
                              ? Colors.red[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.open_in_new, color: Colors.blue[600], size: 22),
                    onPressed: () => _openReport(report),
                    tooltip: 'Open',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: Icon(Icons.share, color: tc.iconColor, size: 22),
                    onPressed: () => _shareReport(report),
                    tooltip: 'Share',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[400], size: 22),
                    onPressed: () => _deleteReport(report),
                    tooltip: 'Delete',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReport(GeneratedReport report) async {
    try {
      if (report.filePath.isEmpty) {
        throw Exception('File path is empty');
      }

      final file = File(report.filePath);
      if (await file.exists()) {
        await OpenFile.open(report.filePath);
      } else {
        if (mounted) {
          SweetAlertDialog.error(
            context: context,
            title: 'File Not Found',
            subtitle: 'The file may have been deleted.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Failed to Open File',
          subtitle: e.toString(),
        );
      }
    }
  }

  Future<void> _shareReport(GeneratedReport report) async {
    try {
      if (report.filePath.isEmpty) {
        throw Exception('File path is empty');
      }

      final file = File(report.filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(report.filePath)],
          text: 'Wandry ${report.reportTypeGenerated}',
        );
      } else {
        if (mounted) {
          SweetAlertDialog.error(
            context: context,
            title: 'File Not Found',
            subtitle: 'The file may have been deleted.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Share Failed',
          subtitle: e.toString(),
        );
      }
    }
  }

  // ============================================================
  // UI COMPONENTS
  // ============================================================
  Widget _buildStatCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(color: tc.shadowColor, blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: tc.subtitleColor)),
          if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 11, color: tc.subtitleColor.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tc.textColor)),
    );
  }

  Widget _buildChartCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.borderColor),
        boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _buildUserDistributionChart() {
    final customers = _userStats['totalCustomers'] ?? 0;
    final admins = _userStats['totalAdmins'] ?? 0;
    final total = customers + admins;

    if (total == 0) return _buildEmptyChartMessage('No users in selected period');

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

  Widget _buildEmptyChartMessage(String message) {
    return Container(
      height: 150,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: tc.iconColor, size: 32),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: tc.subtitleColor)),
        ],
      ),
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
                backgroundColor: tc.isDarkMode ? Colors.grey[700] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 14, color: tc.subtitleColor)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: tc.textColor)),
      ],
    );
  }

  Widget _buildRatingDistributionChart(List<int> distribution) {
    final maxValue = distribution.isEmpty ? 0 : distribution.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return _buildEmptyChartMessage('No feedback in selected period');

    return Column(
      children: List.generate(5, (index) {
        final rating = 5 - index;
        final count = distribution[rating - 1];
        final percentage = maxValue > 0 ? count / maxValue : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text('$rating', style: TextStyle(fontWeight: FontWeight.w500, color: tc.textColor))),
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 24, decoration: BoxDecoration(color: tc.isDarkMode ? Colors.grey[700] : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(height: 24, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 32, child: Text('$count', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w500, color: tc.textColor))),
            ],
          ),
        );
      }),
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
            Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: tc.textColor)),
            Text('$value / $total (${(percentage * 100).toStringAsFixed(1)}%)', style: TextStyle(color: tc.subtitleColor, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(height: 12, decoration: BoxDecoration(color: tc.isDarkMode ? Colors.grey[700] : Colors.grey[200], borderRadius: BorderRadius.circular(6))),
            FractionallySizedBox(
              widthFactor: percentage,
              child: Container(height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentUsersCard() {
    final recentUsers = _userList.take(10).toList();
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.borderColor),
        boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: recentUsers.isEmpty
            ? [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Icon(Icons.person_off, color: tc.iconColor, size: 40),
              const SizedBox(height: 8),
              Text('No users registered in this period', style: TextStyle(color: tc.subtitleColor)),
            ]),
          )
        ]
            : recentUsers.map((user) => ListTile(
          leading: CircleAvatar(
            backgroundColor: user['role'] == 'Admin'
                ? (tc.isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange[100])
                : (tc.isDarkMode ? Colors.blue.withOpacity(0.2) : Colors.blue[100]),
            child: Icon(user['role'] == 'Admin' ? Icons.admin_panel_settings : Icons.person,
                color: user['role'] == 'Admin' ? Colors.orange : Colors.blue, size: 20),
          ),
          title: Text(user['email'] ?? 'N/A', style: TextStyle(fontSize: 14, color: tc.textColor), overflow: TextOverflow.ellipsis),
          subtitle: Text(
            user['registrationDate'] != null
                ? DateFormat('MMM dd, yyyy HH:mm').format((user['registrationDate'] as Timestamp).toDate())
                : 'N/A',
            style: TextStyle(fontSize: 12, color: tc.subtitleColor),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: user['role'] == 'Admin'
                  ? (tc.isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange[50])
                  : (tc.isDarkMode ? Colors.blue.withOpacity(0.2) : Colors.blue[50]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(user['role'] ?? 'N/A',
                style: TextStyle(fontSize: 11, color: user['role'] == 'Admin' ? Colors.orange : Colors.blue)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildRecentFeedbackCard() {
    final recentFeedback = _feedbackList.take(10).toList();
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.borderColor),
        boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: recentFeedback.isEmpty
            ? [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Icon(Icons.feedback_outlined, color: tc.iconColor, size: 40),
              const SizedBox(height: 8),
              Text('No feedback in this period', style: TextStyle(color: tc.subtitleColor)),
            ]),
          )
        ]
            : recentFeedback.map((feedback) => ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: tc.isDarkMode ? Colors.amber.withOpacity(0.2) : Colors.amber[50], borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 2),
              Text('${feedback['rating'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: tc.textColor)),
            ]),
          ),
          title: Text(feedback['userEmail'] ?? 'N/A', style: TextStyle(fontSize: 14, color: tc.textColor), overflow: TextOverflow.ellipsis),
          subtitle: Text(
            (feedback['comment']?.toString().isNotEmpty ?? false) ? feedback['comment'] : 'No comment',
            style: TextStyle(fontSize: 12, color: tc.subtitleColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.borderColor),
        boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        _buildHealthItem('Database', 'Connected', Colors.green),
        Divider(color: tc.dividerColor),
        _buildHealthItem('Authentication', 'Active', Colors.green),
        Divider(color: tc.dividerColor),
        _buildHealthItem('Cloud Functions', 'Running', Colors.green),
      ]),
    );
  }

  Widget _buildHealthItem(String label, String status, Color color) {
    return Row(children: [
      Icon(Icons.check_circle, color: color, size: 20),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(color: tc.textColor)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    ]);
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================
  Future<void> _exportToPdf(ReportType reportType) async {
    setState(() { _isExporting = true; _exportStatus = 'Generating PDF...'; });

    final reportLogID = 'RPT${DateTime.now().millisecondsSinceEpoch}';

    try {
      final pdf = pw.Document();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Wandry ${reportType.label}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Generated: ${DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Period: ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 24),

              if (reportType == ReportType.users || reportType == ReportType.combined) ...[
                pw.Text('User Statistics', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Table.fromTextArray(headers: ['Metric', 'Value'], data: [
                  ['Total Users (in period)', '${_userStats['totalUsers'] ?? 0}'],
                  ['Customers', '${_userStats['totalCustomers'] ?? 0}'],
                  ['Admins', '${_userStats['totalAdmins'] ?? 0}'],
                  ['All Time Total', '${_allUsers.length}'],
                ]),
                pw.SizedBox(height: 24),
              ],

              if (reportType == ReportType.feedback || reportType == ReportType.combined) ...[
                pw.Text('Feedback Statistics', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Table.fromTextArray(headers: ['Metric', 'Value'], data: [
                  ['Total Feedback (in period)', '${_feedbackStats['total'] ?? 0}'],
                  ['Average Rating', '${(_feedbackStats['avgRating'] ?? 0.0).toStringAsFixed(1)}'],
                  ['All Time Total', '${_allFeedback.length}'],
                ]),
                pw.SizedBox(height: 24),
              ],

              if (reportType == ReportType.activity || reportType == ReportType.combined) ...[
                pw.Text('Activity Statistics', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Table.fromTextArray(headers: ['Metric', 'Value'], data: [
                  ['Active Today', '${_activityStats['activeToday'] ?? 0}'],
                  ['Active This Week', '${_activityStats['activeThisWeek'] ?? 0}'],
                  ['Active This Month', '${_activityStats['activeThisMonth'] ?? 0}'],
                  ['Active in Period', '${_activityStats['activeInPeriod'] ?? 0}'],
                ]),
              ],
            ],
          );
        },
      ));

      if ((reportType == ReportType.users || reportType == ReportType.combined) && _userList.isNotEmpty) {
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text('User Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Email', 'Role', 'Registration Date'],
              data: _userList.take(50).map((user) => [
                user['email'] ?? 'N/A',
                user['role'] ?? 'N/A',
                user['registrationDate'] != null ? DateFormat('yyyy-MM-dd').format((user['registrationDate'] as Timestamp).toDate()) : 'N/A',
              ]).toList(),
            ),
          ],
        ));
      }

      if ((reportType == ReportType.feedback || reportType == ReportType.combined) && _feedbackList.isNotEmpty) {
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text('Feedback Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Email', 'Rating', 'Comment'],
              data: _feedbackList.take(50).map((feedback) => [
                feedback['userEmail'] ?? 'N/A',
                '${feedback['rating'] ?? 0}',
                (feedback['comment']?.toString() ?? '').length > 50 ? '${feedback['comment'].toString().substring(0, 50)}...' : feedback['comment'] ?? 'N/A',
              ]).toList(),
            ),
          ],
        ));
      }

      setState(() => _exportStatus = 'Saving file...');

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'wandry_${reportType.name}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      setState(() => _exportStatus = 'Saving to database...');

      final report = GeneratedReport(
        reportLogID: reportLogID,
        adminProfileID: _currentAdminProfileID ?? '',
        reportTypeGenerated: reportType.label,
        startDateParam: _startDate,
        endDateParam: _endDate,
        generationTimestamp: DateTime.now(),
        outputFormat: 'pdf',
        status: ReportStatus.completed.label,
        filePath: filePath,
        fileSize: bytes.length,
      );

      await _firestore.collection('generated_reports').doc(reportLogID).set(report.toMap());
      _generatedReports.insert(0, report);

      setState(() => _isExporting = false);

      if (mounted) {
        SweetAlertDialog.success(
          context: context,
          title: 'PDF Exported Successfully',
          subtitle: 'Your report has been saved and is ready to view.',
          confirmText: 'Open Report',
          onConfirm: () => OpenFile.open(filePath),
        );
        _tabController.animateTo(3);
      }
    } catch (e) {
      print('Error exporting PDF: $e');
      try {
        await _firestore.collection('generated_reports').doc(reportLogID).set({
          'reportLogID': reportLogID, 'adminProfileID': _currentAdminProfileID ?? '',
          'reportTypeGenerated': reportType.label, 'startDateParam': Timestamp.fromDate(_startDate),
          'endDateParam': Timestamp.fromDate(_endDate), 'generationTimestamp': Timestamp.now(),
          'outputFormat': 'pdf', 'status': ReportStatus.failed.label, 'filePath': '', 'fileSize': 0,
        });
      } catch (_) {}

      setState(() => _isExporting = false);
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Export Failed',
          subtitle: 'Failed to export PDF: ${e.toString()}',
        );
      }
    }
  }

  // ============================================================
  // EXCEL EXPORT
  // ============================================================
  Future<void> _exportToExcel(ReportType reportType) async {
    setState(() { _isExporting = true; _exportStatus = 'Generating Excel...'; });

    final reportLogID = 'RPT${DateTime.now().millisecondsSinceEpoch}';

    try {
      final excel = excel_pkg.Excel.createExcel();
      final summarySheet = excel['Summary'];

      summarySheet.appendRow([excel_pkg.TextCellValue('Wandry ${reportType.label}')]);
      summarySheet.appendRow([excel_pkg.TextCellValue('Generated: ${DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now())}')]);
      summarySheet.appendRow([excel_pkg.TextCellValue('Period: ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}')]);
      summarySheet.appendRow([excel_pkg.TextCellValue('')]);

      if (reportType == ReportType.users || reportType == ReportType.combined) {
        summarySheet.appendRow([excel_pkg.TextCellValue('User Statistics')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('Total Users (in period)'), excel_pkg.TextCellValue('${_userStats['totalUsers'] ?? 0}')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('Customers'), excel_pkg.TextCellValue('${_userStats['totalCustomers'] ?? 0}')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('Admins'), excel_pkg.TextCellValue('${_userStats['totalAdmins'] ?? 0}')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('')]);
      }

      if (reportType == ReportType.feedback || reportType == ReportType.combined) {
        summarySheet.appendRow([excel_pkg.TextCellValue('Feedback Statistics')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('Total Feedback'), excel_pkg.TextCellValue('${_feedbackStats['total'] ?? 0}')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('Average Rating'), excel_pkg.TextCellValue('${(_feedbackStats['avgRating'] ?? 0.0).toStringAsFixed(1)}')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('')]);
      }

      if (reportType == ReportType.activity || reportType == ReportType.combined) {
        summarySheet.appendRow([excel_pkg.TextCellValue('Activity Statistics')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('Active Today'), excel_pkg.TextCellValue('${_activityStats['activeToday'] ?? 0}')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('Active This Week'), excel_pkg.TextCellValue('${_activityStats['activeThisWeek'] ?? 0}')]);
        summarySheet.appendRow([excel_pkg.TextCellValue('Active This Month'), excel_pkg.TextCellValue('${_activityStats['activeThisMonth'] ?? 0}')]);
      }

      if (reportType == ReportType.users || reportType == ReportType.combined) {
        final usersSheet = excel['Users'];
        usersSheet.appendRow([excel_pkg.TextCellValue('User ID'), excel_pkg.TextCellValue('Email'), excel_pkg.TextCellValue('Role'), excel_pkg.TextCellValue('Registration Date'), excel_pkg.TextCellValue('Last Login')]);
        for (var user in _userList) {
          usersSheet.appendRow([
            excel_pkg.TextCellValue(user['userID'] ?? ''), excel_pkg.TextCellValue(user['email'] ?? ''), excel_pkg.TextCellValue(user['role'] ?? ''),
            excel_pkg.TextCellValue(user['registrationDate'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((user['registrationDate'] as Timestamp).toDate()) : ''),
            excel_pkg.TextCellValue(user['lastLoginDate'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((user['lastLoginDate'] as Timestamp).toDate()) : ''),
          ]);
        }
      }

      if (reportType == ReportType.feedback || reportType == ReportType.combined) {
        final feedbackSheet = excel['Feedback'];
        feedbackSheet.appendRow([excel_pkg.TextCellValue('Email'), excel_pkg.TextCellValue('Rating'), excel_pkg.TextCellValue('Comment'), excel_pkg.TextCellValue('Date')]);
        for (var feedback in _feedbackList) {
          feedbackSheet.appendRow([
            excel_pkg.TextCellValue(feedback['userEmail'] ?? ''), excel_pkg.TextCellValue('${feedback['rating'] ?? 0}'), excel_pkg.TextCellValue(feedback['comment'] ?? ''),
            excel_pkg.TextCellValue(feedback['createdAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((feedback['createdAt'] as Timestamp).toDate()) : ''),
          ]);
        }
      }

      excel.delete('Sheet1');
      setState(() => _exportStatus = 'Saving file...');

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'wandry_${reportType.name}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final fileBytes = excel.save();

      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        setState(() => _exportStatus = 'Saving to database...');

        final report = GeneratedReport(
          reportLogID: reportLogID, adminProfileID: _currentAdminProfileID ?? '', reportTypeGenerated: reportType.label,
          startDateParam: _startDate, endDateParam: _endDate, generationTimestamp: DateTime.now(),
          outputFormat: 'excel', status: ReportStatus.completed.label, filePath: filePath, fileSize: fileBytes.length,
        );

        await _firestore.collection('generated_reports').doc(reportLogID).set(report.toMap());
        _generatedReports.insert(0, report);
        setState(() => _isExporting = false);

        if (mounted) {
          SweetAlertDialog.success(
            context: context,
            title: 'Excel Exported Successfully',
            subtitle: 'Your report has been saved and is ready to view.',
            confirmText: 'Open Report',
            onConfirm: () => OpenFile.open(filePath),
          );
          _tabController.animateTo(3);
        }
      } else { throw Exception('Failed to generate Excel file'); }
    } catch (e) {
      print('Error exporting Excel: $e');
      try {
        await _firestore.collection('generated_reports').doc(reportLogID).set({
          'reportLogID': reportLogID, 'adminProfileID': _currentAdminProfileID ?? '',
          'reportTypeGenerated': reportType.label, 'startDateParam': Timestamp.fromDate(_startDate),
          'endDateParam': Timestamp.fromDate(_endDate), 'generationTimestamp': Timestamp.now(),
          'outputFormat': 'excel', 'status': ReportStatus.failed.label, 'filePath': '', 'fileSize': 0,
        });
      } catch (_) {}

      setState(() => _isExporting = false);
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Export Failed',
          subtitle: 'Failed to export Excel: ${e.toString()}',
        );
      }
    }
  }
}