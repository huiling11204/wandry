import 'package:flutter/material.dart';
import '../../controller/userAuth.dart';
import '../../controller/admin_service.dart';
import '../../controller/theme_controller.dart';
import '../../widget/sweet_alert_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// AdminDashboard - Main admin dashboard screen with dark mode support
/// Place this in lib/screen/admin/admin_dashboard.dart
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  final AdminService _adminService = AdminService();
  final ThemeController _themeController = ThemeController();

  Map<String, dynamic>? _adminProfile;
  bool _isLoading = true;
  int _selectedIndex = 0;

  // Dashboard stats from Firebase
  int _totalUsers = 0;
  int _totalCustomers = 0;
  int _totalAdmins = 0;
  int _totalFeedback = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  ThemeController get tc => _themeController;

  Future<void> _loadAllData() async {
    await _loadAdminData();
    await _loadDashboardStats();
  }

  Future<void> _loadAdminData() async {
    try {
      User? currentUser = _authService.currentUser;

      if (currentUser != null) {
        Map<String, dynamic>? profile =
        await _authService.getUserProfile(currentUser.uid);

        await _themeController.initializeTheme(currentUser.uid);

        if (mounted) {
          setState(() {
            _adminProfile = profile;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('❌ Error loading admin data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await _adminService.getUserStatistics();
      final feedbackList = await _adminService.getAllFeedback();

      if (mounted) {
        setState(() {
          _totalUsers = stats['totalUsers'] ?? 0;
          _totalCustomers = stats['totalCustomers'] ?? 0;
          _totalAdmins = stats['totalAdmins'] ?? 0;
          _totalFeedback = feedbackList.length;
        });
      }
    } catch (e) {
      print('❌ Error loading dashboard stats: $e');

      if (mounted) {
        setState(() {
          _totalUsers = 0;
          _totalCustomers = 0;
          _totalAdmins = 0;
          _totalFeedback = 0;
        });

        SweetAlertDialog.error(
          context: context,
          title: 'Failed to Load',
          subtitle: 'Could not load dashboard statistics. Please try again.',
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadAllData();
  }

  Future<void> _handleLogout() async {
    final confirm = await SweetAlertDialog.confirm(
      context: context,
      title: 'Logout',
      subtitle: 'Are you sure you want to logout from your admin account?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  void _navigateToUsers() => Navigator.pushNamed(context, '/admin-users');
  void _navigateToFeedback() => Navigator.pushNamed(context, '/admin-feedback');
  void _navigateToReports() => Navigator.pushNamed(context, '/admin-reports');
  void _navigateToSettings() => Navigator.pushNamed(context, '/admin-settings');

  Widget _buildDashboardContent() {
    return Container(
      color: tc.backgroundColor,
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Dashboard', style: tc.titleStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                'Welcome, ${_adminProfile?['profile']?['adminName'] ?? _adminProfile?['email'] ?? 'Admin'}',
                style: tc.subtitleStyle(),
              ),
              const SizedBox(height: 24),

              // Stats Cards
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard('Total Users', _totalUsers.toString(), Icons.people, Colors.blue),
                  _buildStatCard('Customers', _totalCustomers.toString(), Icons.person, Colors.green),
                  _buildStatCard('Admins', _totalAdmins.toString(), Icons.admin_panel_settings, Colors.orange),
                  _buildStatCard('Feedback', _totalFeedback.toString(), Icons.feedback, Colors.purple),
                ],
              ),
              const SizedBox(height: 24),

              Text('Quick Actions', style: tc.titleStyle(fontSize: 16)),
              const SizedBox(height: 12),

              _buildQuickActionCard(
                'User Management',
                'View and manage all users',
                Icons.people_outline,
                Colors.blue,
                _navigateToUsers,
              ),
              const SizedBox(height: 12),
              _buildQuickActionCard(
                'Feedback Management',
                'Review customer feedback',
                Icons.feedback_outlined,
                Colors.purple,
                _navigateToFeedback,
              ),
              const SizedBox(height: 12),
              _buildQuickActionCard(
                'Reports',
                'View system reports',
                Icons.description_outlined,
                Colors.green,
                _navigateToReports,
              ),
              const SizedBox(height: 24),

              // System Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tc.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tc.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: tc.iconColor, size: 20),
                        const SizedBox(width: 8),
                        Text('System Information', style: tc.titleStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Admin ID', _adminProfile?['userID'] ?? 'N/A'),
                    _buildInfoRow('Admin Name', _adminProfile?['profile']?['adminName'] ?? 'N/A'),
                    _buildInfoRow('Email', _adminProfile?['email'] ?? 'N/A'),
                    _buildInfoRow('Role', _adminProfile?['role'] ?? 'N/A'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.isDarkMode ? color.withOpacity(0.15) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: tc.subtitleStyle(fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(tc.isDarkMode ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tc.titleStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: tc.subtitleStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: tc.iconColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: tc.subtitleStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: tc.textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: tc.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue[600]),
              const SizedBox(height: 16),
              Text('Loading admin data...', style: tc.subtitleStyle()),
            ],
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: isMobile
          ? AppBar(
        title: Text('Admin Dashboard', style: TextStyle(color: tc.appBarForegroundColor)),
        backgroundColor: tc.appBarColor,
        iconTheme: IconThemeData(color: tc.appBarForegroundColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      )
          : null,
      drawer: isMobile ? Drawer(backgroundColor: tc.sidebarColor, child: _buildSidebar()) : null,
      body: isMobile
          ? _buildDashboardContent()
          : Row(
        children: [
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: tc.sidebarColor,
              boxShadow: [
                BoxShadow(
                  color: tc.shadowColor,
                  blurRadius: 4,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: _buildSidebar(),
          ),
          Expanded(child: _buildDashboardContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final sidebarTextColor = tc.isDarkMode ? Colors.white : Colors.black87;
    final sidebarSubtitleColor = tc.isDarkMode ? Colors.grey[400] : Colors.black54;

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tc.isDarkMode ? Colors.blue[900] : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.flutter_dash,
                    color: tc.isDarkMode ? Colors.blue[300] : const Color(0xFF6BAED6),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Wandry',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: sidebarTextColor,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: tc.isDarkMode ? Colors.grey[700] : Colors.black12, thickness: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(0, Icons.dashboard, 'Dashboard', () {
                  setState(() => _selectedIndex = 0);
                  if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
                }),
                _buildMenuItem(1, Icons.people, 'Users', () {
                  if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
                  _navigateToUsers();
                }),
                _buildMenuItem(2, Icons.feedback, 'Feedback', () {
                  if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
                  _navigateToFeedback();
                }),
                _buildMenuItem(3, Icons.description, 'Reports', () {
                  if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
                  _navigateToReports();
                }),
                _buildMenuItem(4, Icons.settings, 'Settings', () {
                  if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
                  _navigateToSettings();
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red[400]!, Colors.red[300]!]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleLogout,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
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

  Widget _buildMenuItem(int index, IconData icon, String title, VoidCallback onTap) {
    final isSelected = _selectedIndex == index;
    final sidebarTextColor = tc.isDarkMode ? Colors.white : Colors.black87;
    final sidebarSubtitleColor = tc.isDarkMode ? Colors.grey[400] : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (tc.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? sidebarTextColor : sidebarSubtitleColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? sidebarTextColor : sidebarSubtitleColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}