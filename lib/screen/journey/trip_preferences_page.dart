import 'package:flutter/material.dart';
import 'package:wandry/controller/destination_search_controller.dart';
import 'package:wandry/widget/destination_autocomplete_widget.dart';
import 'package:wandry/widget/budget_selector_widget.dart';
import 'package:wandry/widget/progress_indicator_widget.dart';
import 'package:wandry/widget/destination_type_selector_widget.dart';
import 'package:wandry/model/destination_type_model.dart';
import 'package:wandry/utilities/date_formatter.dart';
import 'trip_generation_loading.dart';

class TripPreferencesPage extends StatefulWidget {
  final String tripName;
  final String tripDescription;

  const TripPreferencesPage({
    super.key,
    required this.tripName,
    required this.tripDescription,
  });

  @override
  State<TripPreferencesPage> createState() => _TripPreferencesPageState();
}

class _TripPreferencesPageState extends State<TripPreferencesPage> {
  final _formKey = GlobalKey<FormState>();
  late DestinationSearchController _searchController;

  // Form fields
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  DateTime? _startDate;
  DateTime? _endDate;
  String _budgetLevel = 'Medium';

  // NEW: Destination type preferences
  List<String> _selectedDestinationTypes = ['relaxing']; // Default selection

  // Search state
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedDestination;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _searchController = DestinationSearchController();
    _setupSearchController();
    _destinationController.addListener(_onDestinationChanged);
    _destinationFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _setupSearchController() {
    _searchController.onSearchStateChanged = (isSearching) {
      setState(() => _isSearching = isSearching);
    };

    _searchController.onResultsChanged = (results) {
      setState(() => _searchResults = results);
      if (results.isNotEmpty && _destinationFocusNode.hasFocus) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    };

    _searchController.onError = (error) {
      print('Search error: $error');
      // User can simply try typing again
    };
  }

  void _onDestinationChanged() {
    final query = _destinationController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      _removeOverlay();
      return;
    }

    if (_selectedDestination != null &&
        _destinationController.text != _selectedDestination!['display_name']) {
      setState(() => _selectedDestination = null);
    }

    _searchController.searchDestination(query);
  }

  void _onFocusChanged() {
    if (!_destinationFocusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => DestinationAutocompleteWidget(
        searchResults: _searchResults,
        layerLink: _layerLink,
        onSelectDestination: _onSelectDestination,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSelectDestination(Map<String, dynamic> place) {
    final displayName = _searchController.formatDestinationDisplay(place);
    final address = place['address'] as Map<String, dynamic>?;
    final city = address?['city']?.toString() ?? '';
    final country = address?['country']?.toString() ?? '';

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
                const ProgressIndicatorWidget(currentStep: 2, totalSteps: 3),
                const SizedBox(height: 32),

                // Destination field
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
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                              : DateFormatter.formatDate(_startDate!),
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
                  onTap: _startDate == null ? null : () => _selectEndDate(context),
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
                              : DateFormatter.formatDate(_endDate!),
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
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                BudgetSelectorWidget(
                  selectedBudget: _budgetLevel,
                  onBudgetSelected: (budget) => setState(() => _budgetLevel = budget),
                ),
                const SizedBox(height: 24),

                // NEW: Destination Type Preferences
                Row(
                  children: [
                    const Text(
                      'Trip Style',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Personalize your itinerary based on your interests',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                DestinationTypeSelectorWidget(
                  selectedTypeIds: _selectedDestinationTypes,
                  onSelectionChanged: (types) {
                    setState(() {
                      _selectedDestinationTypes = types;
                    });
                  },
                  maxSelection: 3,
                  minSelection: 1,
                ),
                const SizedBox(height: 32),

                // Generate button
                ElevatedButton(
                  onPressed: _startDate != null &&
                      _endDate != null &&
                      _selectedDestinationTypes.isNotEmpty
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
                const SizedBox(height: 16),

                // Selected preferences summary
                if (_selectedDestinationTypes.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 16,
                                color: Colors.green[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Your trip will focus on:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DestinationTypeChips(typeIds: _selectedDestinationTypes),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF4A90E2)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF4A90E2)),
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

      if (_selectedDestinationTypes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one trip style')),
        );
        return;
      }

      final extracted = _searchController.extractCityAndCountry(
        _selectedDestination,
        _destinationController.text.trim(),
      );

      final city = extracted['city']!;
      final country = extracted['country']!;

      if (city.isEmpty || country.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot determine city and country from destination. Please try selecting a different destination.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      print('🔍 Destination Information:');
      print('   Display Name: ${_destinationController.text}');
      print('   City: $city');
      print('   Country: $country');
      print('   Trip Styles: $_selectedDestinationTypes');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripGenerationLoadingPage(
            tripName: widget.tripName,
            tripDescription: widget.tripDescription,
            destination: _destinationController.text,
            city: city,
            country: country,
            startDate: _startDate!,
            endDate: _endDate!,
            budgetLevel: _budgetLevel,
            destinationData: _selectedDestination,
            destinationTypes: _selectedDestinationTypes, // NEW
          ),
        ),
      );
    }
  }
}