import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trip_generation_loading.dart';

class TripPreferencesPage extends StatefulWidget {
  final String tripName;
  final String tripDescription;

  const TripPreferencesPage({
    Key? key,
    required this.tripName,
    required this.tripDescription,
  }) : super(key: key);

  @override
  State<TripPreferencesPage> createState() => _TripPreferencesPageState();
}

class _TripPreferencesPageState extends State<TripPreferencesPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _destinationController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _budgetLevel = 'Medium';

  // Autocomplete state
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _destinationFocusNode = FocusNode();

  // Selected destination details
  Map<String, dynamic>? _selectedDestination;

  final String _searchUrl =
      "https://us-central1-trip-planner-ec182.cloudfunctions.net/searchDestinations";

  @override
  void initState() {
    super.initState();
    _destinationController.addListener(_onDestinationChanged);
    _destinationFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _destinationController.removeListener(_onDestinationChanged);
    _destinationFocusNode.removeListener(_onFocusChanged);
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_destinationFocusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onDestinationChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = _destinationController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      _removeOverlay();
      return;
    }

    // If user is typing, clear selected destination
    if (_selectedDestination != null &&
        _destinationController.text != _selectedDestination!['display_name']) {
      _selectedDestination = null;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchDestination(query);
    });
  }

  Future<void> _searchDestination(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final response = await http.post(
        Uri.parse(_searchUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'limit': 10}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(data['results'] ?? []);
            _isSearching = false;
          });

          if (_searchResults.isNotEmpty && _destinationFocusNode.hasFocus) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
        }
      }
    } catch (e) {
      setState(() => _isSearching = false);
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  return _buildSuggestionItem(place);
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionItem(Map<String, dynamic> place) {
    final name = place['name']?.toString() ?? 'Unknown';
    final address = place['address'] as Map<String, dynamic>?;
    final city = address?['city']?.toString() ?? '';
    final country = address?['country']?.toString() ?? '';

    String subtitle = '';
    if (city.isNotEmpty && country.isNotEmpty) {
      subtitle = '$city, $country';
    } else if (city.isNotEmpty) {
      subtitle = city;
    } else if (country.isNotEmpty) {
      subtitle = country;
    }

    // Create display name
    String displayName = name;
    if (subtitle.isNotEmpty) {
      displayName = '$name, $subtitle';
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDestination = {
            ...place,
            'display_name': displayName,
            'city': city,
            'country': country,
          };
          _destinationController.text = displayName;
        });
        _removeOverlay();
        _destinationFocusNode.unfocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                size: 20,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trip Preferences',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Progress indicator
                _buildProgressIndicator(),
                const SizedBox(height: 32),

                // Destination field with autocomplete
                const Text(
                  'Where to?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                CompositedTransformTarget(
                  link: _layerLink,
                  child: TextFormField(
                    controller: _destinationController,
                    focusNode: _destinationFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search city or country',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
                      suffixIcon: _isSearching
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                          ),
                        ),
                      )
                          : _destinationController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _destinationController.clear();
                            _selectedDestination = null;
                            _searchResults.clear();
                          });
                          _removeOverlay();
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a destination';
                      }
                      if (_selectedDestination == null) {
                        return 'Please select a destination from the suggestions';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start typing to see suggestions',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Start Date
                const Text(
                  'Start Date',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectStartDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
                        const SizedBox(width: 12),
                        Text(
                          _startDate == null
                              ? 'Select start date'
                              : _formatDate(_startDate!),
                          style: TextStyle(
                            fontSize: 16,
                            color: _startDate == null ? Colors.grey[600] : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // End Date
                const Text(
                  'End Date',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _startDate == null
                      ? null
                      : () => _selectEndDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _startDate == null ? Colors.grey[100] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _startDate == null ? Colors.grey[200]! : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: _startDate == null ? Colors.grey[400] : const Color(0xFF4A90E2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _endDate == null
                              ? 'Select end date'
                              : _formatDate(_endDate!),
                          style: TextStyle(
                            fontSize: 16,
                            color: _endDate == null ? Colors.grey[600] : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_startDate == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Please select start date first',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Budget Level
                const Text(
                  'Budget Level',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildBudgetChip('Low', Icons.attach_money),
                    const SizedBox(width: 12),
                    _buildBudgetChip('Medium', Icons.monetization_on),
                    const SizedBox(width: 12),
                    _buildBudgetChip('High', Icons.diamond),
                  ],
                ),
                const SizedBox(height: 32),

                // Generate button
                ElevatedButton(
                  onPressed: _startDate != null && _endDate != null
                      ? _generateTrip
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Generate Trip Plan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        _buildProgressDot(true, 1),
        _buildProgressLine(true),
        _buildProgressDot(true, 2),
        _buildProgressLine(false),
        _buildProgressDot(false, 3),
      ],
    );
  }

  Widget _buildProgressDot(bool isActive, int step) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF4A90E2) : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? const Color(0xFF4A90E2) : Colors.grey[300],
      ),
    );
  }

  Widget _buildBudgetChip(String label, IconData icon) {
    final isSelected = _budgetLevel == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _budgetLevel = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4A90E2).withOpacity(0.1)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)), // 2 years
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A90E2),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before new start date
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    if (_startDate == null) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate!.add(const Duration(days: 1)),
      firstDate: _startDate!,
      lastDate: _startDate!.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A90E2),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _generateTrip() {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both start and end dates')),
        );
        return;
      }

      if (_selectedDestination == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid destination')),
        );
        return;
      }

      // Extract city and country
      final city = _selectedDestination!['city'] ?? '';
      final country = _selectedDestination!['country'] ?? '';

      // Navigate to loading/generation page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripGenerationLoading(
            tripName: widget.tripName,
            tripDescription: widget.tripDescription,
            destination: _destinationController.text,
            city: city,
            country: country,
            startDate: _startDate!,
            endDate: _endDate!,
            budgetLevel: _budgetLevel,
            destinationData: _selectedDestination,
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}