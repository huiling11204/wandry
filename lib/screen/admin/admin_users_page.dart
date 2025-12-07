import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../controller/admin_service.dart';
import '../../controller/theme_controller.dart';
import '../../widget/sweet_alert_dialog.dart';

/// User management screen (VIEW ONLY - No Delete)
/// Admins can view user information but cannot delete accounts
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final ThemeController _themeController = ThemeController();
  late TabController _tabController;

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
    _themeController.addListener(_onThemeChanged);
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

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _adminService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Failed to Load',
          subtitle: _adminService.getErrorMessage(e),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    List<Map<String, dynamic>> filtered = _users;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final email = user['email']?.toString().toLowerCase() ?? '';
        final userId = user['userID']?.toString().toLowerCase() ?? '';
        final role = user['role']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return email.contains(query) ||
            userId.contains(query) ||
            role.contains(query);
      }).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> get _allUsers => _filteredUsers;
  List<Map<String, dynamic>> get _customerUsers =>
      _filteredUsers.where((u) => u['role'] == 'Customer').toList();
  List<Map<String, dynamic>> get _adminUsers =>
      _filteredUsers.where((u) => u['role'] == 'Admin').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        title: Text(
          'User Management',
          style: TextStyle(color: tc.appBarForegroundColor),
        ),
        backgroundColor: tc.appBarColor,
        iconTheme: IconThemeData(color: tc.appBarForegroundColor),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: tc.appBarColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: tc.isDarkMode ? Colors.blue[400] : Colors.blue[700],
              indicatorWeight: 3,
              labelColor: tc.appBarForegroundColor,
              unselectedLabelColor: tc.appBarForegroundColor.withOpacity(0.6),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              tabs: [
                Tab(text: 'All (${_allUsers.length})'),
                Tab(text: 'Customers (${_customerUsers.length})'),
                Tab(text: 'Admins (${_adminUsers.length})'),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        color: tc.backgroundColor,
        child: Column(
          children: [
            // Info Banner
            Container(
              color: Colors.blue.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'View-only mode. Customers can delete their own accounts. Contact system admin to manage admin accounts.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              color: tc.cardColor,
              padding: const EdgeInsets.all(16),
              child: TextField(
                style: TextStyle(color: tc.textColor),
                decoration: InputDecoration(
                  hintText: 'Search by email, user ID, or role...',
                  hintStyle: TextStyle(color: tc.hintColor),
                  prefixIcon: Icon(Icons.search, color: tc.iconColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: tc.iconColor),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: tc.inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.blue[600]))
                  : TabBarView(
                controller: _tabController,
                children: [
                  _buildUserList(_allUsers),
                  _buildUserList(_customerUsers),
                  _buildUserList(_adminUsers),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tc.cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline, size: 48, color: tc.iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                color: tc.textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Users will appear here',
              style: tc.subtitleStyle(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] ?? 'Unknown';
    final email = user['email'] ?? 'No email';
    final userId = user['userID'] ?? 'No ID';
    final profile = user['profile'];

    String name = 'Unknown User';
    String? avatarLetter;

    if (profile != null) {
      if (role == 'Customer') {
        final firstName = profile['firstName'] ?? '';
        final lastName = profile['lastName'] ?? '';
        name = '$firstName $lastName'.trim();
        if (name.isEmpty) name = 'Unknown Customer';
        avatarLetter = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'C';
      } else if (role == 'Admin') {
        name = profile['adminName'] ?? 'Unknown Admin';
        avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : 'A';
      }
    } else {
      avatarLetter = role == 'Admin' ? 'A' : 'C';
    }

    final regDate = user['registrationDate'] != null
        ? DateFormat('MMM dd, yyyy')
        .format((user['registrationDate'] as dynamic).toDate())
        : 'Unknown';

    final isAdmin = role == 'Admin';
    final roleColor = isAdmin ? Colors.orange : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUserDetails(user),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top Row: Avatar, Name, Email, Role Badge
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAdmin
                              ? [Colors.orange[300]!, Colors.orange[500]!]
                              : [Colors.blue[300]!, Colors.blue[500]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          avatarLetter ?? '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name & Email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: tc.textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: tc.subtitleStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(tc.isDarkMode ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAdmin ? Icons.admin_panel_settings : Icons.person,
                            size: 12,
                            color: roleColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            role,
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bottom Row: User ID, Date, View Action
                Row(
                  children: [
                    // User ID
                    Icon(Icons.badge_outlined, size: 14, color: tc.iconColor),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 2,
                      child: Text(
                        userId,
                        style: TextStyle(fontSize: 11, color: tc.subtitleColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Date
                    Icon(Icons.calendar_today_outlined, size: 14, color: tc.iconColor),
                    const SizedBox(width: 4),
                    Text(
                      regDate,
                      style: TextStyle(fontSize: 11, color: tc.subtitleColor),
                    ),

                    const SizedBox(width: 8),

                    // View Button (No Delete)
                    InkWell(
                      onTap: () => _showUserDetails(user),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.visibility_outlined, size: 18, color: Colors.blue[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final role = user['role'] ?? 'Unknown';
    final isAdmin = role == 'Admin';
    final roleColor = isAdmin ? Colors.orange : Colors.blue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tc.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isAdmin
                            ? [Colors.orange[300]!, Colors.orange[500]!]
                            : [Colors.blue[300]!, Colors.blue[500]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Details',
                          style: tc.titleStyle(fontSize: 20),
                        ),
                        Text(
                          user['email'] ?? 'No email',
                          style: tc.subtitleStyle(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: tc.dividerColor),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Account Information', [
                      _buildDetailItem('User ID', user['userID'] ?? 'N/A'),
                      _buildDetailItem('Firebase UID', user['firebaseUid'] ?? 'N/A'),
                      _buildDetailItem('Email', user['email'] ?? 'N/A'),
                      _buildDetailItem('Role', user['role'] ?? 'N/A'),
                    ]),

                    const SizedBox(height: 20),

                    _buildDetailSection('Activity', [
                      _buildDetailItem(
                        'Registration Date',
                        user['registrationDate'] != null
                            ? DateFormat('MMMM dd, yyyy - HH:mm').format(
                            (user['registrationDate'] as dynamic).toDate())
                            : 'N/A',
                      ),
                      _buildDetailItem(
                        'Last Login',
                        user['lastLoginDate'] != null
                            ? DateFormat('MMMM dd, yyyy - HH:mm').format(
                            (user['lastLoginDate'] as dynamic).toDate())
                            : 'Never',
                      ),
                    ]),

                    if (user['profile'] != null) ...[
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        'Profile Information',
                        (user['profile'] as Map<String, dynamic>)
                            .entries
                            .map((entry) => _buildDetailItem(
                          _formatFieldName(entry.key),
                          _formatFieldValue(entry.value),
                        ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Close Action Only (No Delete)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tc.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: tc.shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tc.subtitleColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: tc.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tc.borderColor),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tc.dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: tc.subtitleStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: tc.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .replaceFirstMapped(RegExp(r'^.'), (match) => match.group(0)!.toUpperCase())
        .trim();
  }

  String _formatFieldValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is Timestamp) {
      return DateFormat('MMMM dd, yyyy - HH:mm').format(value.toDate());
    }
    return value.toString();
  }
}