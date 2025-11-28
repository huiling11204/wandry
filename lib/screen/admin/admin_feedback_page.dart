import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../controller/admin_service.dart';
import '../../controller/theme_controller.dart';
import '../../widget/sweet_alert_dialog.dart';

/// AdminFeedbackPage - Feedback management screen (FIXED OVERFLOW)
/// Place this in lib/screen/admin/admin_feedback_page.dart
class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});

  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  final AdminService _adminService = AdminService();
  final ThemeController _themeController = ThemeController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _feedbackList = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _selectedRatingFilter = 0;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
    _themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  ThemeController get tc => _themeController;

  Future<void> _loadFeedback() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final feedback = await _adminService.getAllFeedback();
      setState(() {
        _feedbackList = feedback;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading feedback: $e');
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

  List<Map<String, dynamic>> get _filteredFeedback {
    List<Map<String, dynamic>> filtered = _feedbackList;

    if (_selectedRatingFilter > 0) {
      filtered = filtered.where((feedback) {
        final rating = feedback['rating'] ?? 0;
        return rating == _selectedRatingFilter;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((feedback) {
        final email = feedback['userEmail']?.toString().toLowerCase() ?? '';
        final comment = feedback['comment']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return email.contains(query) || comment.contains(query);
      }).toList();
    }

    return filtered;
  }

  double get _averageRating {
    if (_feedbackList.isEmpty) return 0;
    final sum = _feedbackList.fold<int>(
        0, (prev, f) => prev + ((f['rating'] ?? 0) as int));
    return sum / _feedbackList.length;
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedRatingFilter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tc.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Feedback Management',
          style: TextStyle(color: tc.appBarForegroundColor),
        ),
        backgroundColor: tc.appBarColor,
        iconTheme: IconThemeData(color: tc.appBarForegroundColor),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFeedback,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        color: tc.backgroundColor,
        child: Column(
          children: [
            // Stats Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[600]!, Colors.purple[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.feedback_outlined,
                      label: 'Total',
                      value: '${_feedbackList.length}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.star,
                      label: 'Avg Rating',
                      value: _averageRating.toStringAsFixed(1),
                    ),
                  ),
                ],
              ),
            ),

            // Search and Filter Section
            Container(
              color: tc.cardColor,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar - FIXED: Added scrollPadding to prevent overflow
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: tc.textColor),
                    scrollPadding: const EdgeInsets.only(bottom: 100),
                    decoration: InputDecoration(
                      hintText: 'Search by email or comment...',
                      hintStyle: TextStyle(color: tc.hintColor),
                      prefixIcon: Icon(Icons.search, color: tc.iconColor),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: tc.iconColor),
                        onPressed: () {
                          _searchController.clear();
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // Rating Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 0),
                        _buildFilterChip('⭐ 1', 1),
                        _buildFilterChip('⭐ 2', 2),
                        _buildFilterChip('⭐ 3', 3),
                        _buildFilterChip('⭐ 4', 4),
                        _buildFilterChip('⭐ 5', 5),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Count Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: tc.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
              child: Row(
                children: [
                  Icon(Icons.feedback_outlined, size: 16, color: tc.iconColor),
                  const SizedBox(width: 8),
                  Text(
                    '${_filteredFeedback.length} feedback entries',
                    style: TextStyle(
                      color: tc.subtitleColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Feedback List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.purple[600]))
                  : _filteredFeedback.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                onRefresh: _loadFeedback,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredFeedback.length,
                  itemBuilder: (context, index) {
                    final feedback = _filteredFeedback[index];
                    return _buildFeedbackCard(feedback);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int rating) {
    final isSelected = _selectedRatingFilter == rating;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedRatingFilter = rating;
          });
        },
        backgroundColor: tc.cardColor,
        selectedColor: Colors.amber.withOpacity(0.2),
        checkmarkColor: Colors.amber[700],
        labelStyle: TextStyle(
          color: isSelected ? Colors.amber[800] : tc.subtitleColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        side: BorderSide(
          color: isSelected ? Colors.amber : tc.borderColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  // IMPROVED EMPTY STATE
  // IMPROVED EMPTY STATE - Fixed overflow when keyboard is open
  Widget _buildEmptyState() {
    final hasFilters = _searchQuery.isNotEmpty || _selectedRatingFilter > 0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters ? Icons.search_off : Icons.feedback_outlined,
                size: 48,
                color: Colors.purple[400],
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              hasFilters ? 'No Results Found' : 'No Feedback Yet',
              style: TextStyle(
                fontSize: 20,
                color: tc.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters'
                  : 'Customer feedback will appear here',
              style: tc.subtitleStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),

            // Clear Filters Button
            if (hasFilters) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off, size: 18),
                label: const Text('Clear All Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple[600],
                  side: BorderSide(color: Colors.purple[300]!),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final email = feedback['userEmail'] ?? 'Unknown';
    final comment = feedback['comment'] ?? '';
    final rating = feedback['rating'] ?? 0;

    String timestamp = 'Unknown';
    if (feedback['createdAt'] != null) {
      try {
        timestamp = DateFormat('MMM dd, yyyy • HH:mm')
            .format((feedback['createdAt'] as Timestamp).toDate());
      } catch (e) {
        print('Error parsing createdAt: $e');
      }
    } else if (feedback['timestamp'] != null) {
      try {
        timestamp = DateFormat('MMM dd, yyyy • HH:mm')
            .format((feedback['timestamp'] as Timestamp).toDate());
      } catch (e) {
        print('Error parsing timestamp: $e');
      }
    }

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
          onTap: () => _showFullFeedback(feedback),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple[400]!, Colors.purple[600]!],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          email.isNotEmpty ? email[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Email & Time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: tc.textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timestamp,
                            style: tc.subtitleStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    // Rating Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber[600]!, Colors.amber[400]!],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$rating',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Star Display
                _buildStarRating(rating, size: 18),

                // Comment
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tc.isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      comment,
                      style: TextStyle(
                        color: tc.textColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // View Details
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showFullFeedback(feedback),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.purple[600],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('View', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStarRating(int rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  void _showFullFeedback(Map<String, dynamic> feedback) {
    final rating = feedback['rating'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tc.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.star, color: Colors.amber, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Feedback Details', style: tc.titleStyle(fontSize: 20)),
                        _buildStarRating(rating, size: 20),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber[600]!, Colors.amber[400]!],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$rating/5',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: tc.dividerColor),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection('From', [
                      _buildInfoRow(Icons.email_outlined, feedback['userEmail'] ?? 'N/A'),
                      _buildInfoRow(
                        Icons.access_time,
                        feedback['createdAt'] != null
                            ? DateFormat('MMMM dd, yyyy • HH:mm').format(
                            (feedback['createdAt'] as Timestamp).toDate())
                            : 'Unknown',
                      ),
                    ]),

                    const SizedBox(height: 24),

                    Text('Rating', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitleColor)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          _buildStarRating(rating, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            _getRatingLabel(rating),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text('Comment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitleColor)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tc.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tc.borderColor),
                      ),
                      child: Text(
                        (feedback['comment']?.toString().isNotEmpty ?? false)
                            ? feedback['comment']
                            : 'No comment provided',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: (feedback['comment']?.toString().isNotEmpty ?? false)
                              ? tc.textColor
                              : tc.subtitleColor,
                          fontStyle: (feedback['comment']?.toString().isNotEmpty ?? false)
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tc.cardColor,
                boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return 'No Rating';
    }
  }

  Widget _buildInfoSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitleColor)),
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

  Widget _buildInfoRow(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tc.dividerColor))),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tc.iconColor),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: tc.textColor))),
        ],
      ),
    );
  }
}