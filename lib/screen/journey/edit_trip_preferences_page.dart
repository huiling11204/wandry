// Page for editing trip preferences (destination, dates, budget, styles)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wandry/controller/trip_edit_controller.dart';
import 'package:wandry/controller/destination_search_controller.dart';
import 'package:wandry/widget/destination_type_selector_widget.dart';

class EditTripPreferencesPage extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> tripData;

  const EditTripPreferencesPage({
    super.key,
    required this.tripId,
    required this.tripData,
  });

  @override
  State<EditTripPreferencesPage> createState() => _EditTripPreferencesPageState();
}

class _EditTripPreferencesPageState extends State<EditTripPreferencesPage> {
  final TripEditController _editController = TripEditController();
  final DestinationSearchController _searchController = DestinationSearchController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _tripNameController = TextEditingController();

  // Form state
  String _city = '';
  String _country = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String _budgetLevel = 'Medium';
  List<String> _destinationTypes = ['relaxing'];
  bool _halalOnly = false;

  // UI state
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isRegenerating = false;
  int _regenerationProgress = 0;
  String _regenerationMessage = '';
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedDestination;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeFromTripData();
    _setupControllers();
  }

  void _initializeFromTripData() {
    final data = widget.tripData;

    _tripNameController.text = data['tripName'] ?? '';
    _city = data['destinationCity'] ?? data['city'] ?? '';
    _country = data['destinationCountry'] ?? data['country'] ?? '';
    _destinationController.text = '$_city, $_country';

    _startDate = _parseDate(data['startDate']);
    _endDate = _parseDate(data['endDate']);
    _budgetLevel = data['budgetLevel'] ?? 'Medium';
    _destinationTypes = (data['destinationTypes'] as List?)?.cast<String>() ?? ['relaxing'];
    _halalOnly = data['halalOnly'] ?? false;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    // Handle Firestore Timestamp
    try {
      return value.toDate();
    } catch (e) {
      return null;
    }
  }

  void _setupControllers() {
    _editController.onLoadingChanged = (isLoading) {
      if (mounted) setState(() => _isLoading = isLoading);
    };

    _editController.onError = (message) {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    };

    _editController.onSuccess = (message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    };

    _editController.onRegenerationProgress = (progress, message) {
      if (mounted) {
        setState(() {
          _regenerationProgress = progress;
          _regenerationMessage = message;
        });
      }
    };

    _editController.onRegenerationComplete = (tripId) {
      if (mounted) {
        setState(() => _isRegenerating = false);
        Navigator.pop(context, true); // Return true to indicate changes made
      }
    };

    // Destination search
    _searchController.onSearchStateChanged = (isSearching) {
      if (mounted) setState(() => _isSearching = isSearching);
    };

    _searchController.onResultsChanged = (results) {
      if (mounted) setState(() => _searchResults = results);
    };
  }

  @override
  void dispose() {
    _editController.dispose();
    _searchController.dispose();
    _destinationController.dispose();
    _tripNameController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    final originalData = widget.tripData;

    final hasChanges = TripEditController.requiresRegeneration(
      originalData: originalData,
      newCity: _city,
      newCountry: _country,
      newStartDate: _startDate,
      newEndDate: _endDate,
      newBudgetLevel: _budgetLevel,
      newDestinationTypes: _destinationTypes,
    ) || _tripNameController.text != (originalData['tripName'] ?? '');

    setState(() => _hasChanges = hasChanges);
  }

  @override
  Widget build(BuildContext context) {
    if (_isRegenerating) {
      return _buildRegeneratingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Trip'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip Name
            _buildSection(
              title: 'Trip Name',
              child: TextField(
                controller: _tripNameController,
                decoration: InputDecoration(
                  hintText: 'Enter trip name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (_) => _checkForChanges(),
              ),
            ),

            // Destination
            _buildSection(
              title: 'Destination',
              child: Column(
                children: [
                  TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: 'Search destination...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (query) {
                      _searchController.searchDestination(query);
                    },
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.place),
                            title: Text(result['name'] ?? ''),
                            subtitle: Text(
                              '${result['city'] ?? ''}, ${result['country'] ?? ''}',
                            ),
                            onTap: () {
                              setState(() {
                                _selectedDestination = result;
                                _city = result['city'] ?? result['name'] ?? '';
                                _country = result['country'] ?? '';
                                _destinationController.text = '$_city, $_country';
                                _searchResults = [];
                              });
                              _checkForChanges();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Dates
            _buildSection(
              title: 'Travel Dates',
              child: Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'Start',
                      date: _startDate,
                      onTap: () => _selectDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateField(
                      label: 'End',
                      date: _endDate,
                      onTap: () => _selectDate(isStart: false),
                    ),
                  ),
                ],
              ),
            ),

            // Budget Level
            _buildSection(
              title: 'Budget Level',
              child: Row(
                children: [
                  _buildBudgetOption('Low', Icons.savings),
                  const SizedBox(width: 12),
                  _buildBudgetOption('Medium', Icons.account_balance_wallet),
                  const SizedBox(width: 12),
                  _buildBudgetOption('High', Icons.diamond),
                ],
              ),
            ),

            // Destination Types
            _buildSection(
              title: 'Trip Style',
              subtitle: 'Select what kind of experiences you prefer',
              child: DestinationTypeSelectorWidget(
                selectedTypeIds: _destinationTypes,
                onSelectionChanged: (types) {
                  setState(() => _destinationTypes = types);
                  _checkForChanges();
                },
              ),
            ),

            // Halal Option
            _buildSection(
              title: 'Dietary Preferences',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Halal restaurants only'),
                subtitle: Text(
                  'Show only halal-certified restaurant options',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                value: _halalOnly,
                onChanged: (value) {
                  setState(() => _halalOnly = value);
                  _checkForChanges();
                },
              ),
            ),

            const SizedBox(height: 24),

            // Warning about regeneration
            if (_hasChanges && _requiresRegeneration())
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Itinerary Regeneration Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'These changes will regenerate your entire itinerary. This takes 30-60 seconds.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _hasChanges
          ? SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _requiresRegeneration() ? 'Save & Regenerate' : 'Save Changes',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  date != null
                      ? DateFormat('MMM d, y').format(date)
                      : 'Select date',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetOption(String level, IconData icon) {
    final isSelected = _budgetLevel == level;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _budgetLevel = level);
          _checkForChanges();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2196F3) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(height: 4),
              Text(
                level,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegeneratingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _AnimatedRegeneratingIcon(),
                const SizedBox(height: 32),
                const Text(
                  'Regenerating Itinerary',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_city, $_country',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                Text(
                  '$_regenerationProgress%',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _regenerationProgress / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _regenerationMessage.isNotEmpty ? _regenerationMessage : 'Processing...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w500,
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

  Future<void> _selectDate({required bool isStart}) async {
    final initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());

    final firstDate = isStart ? DateTime.now() : (_startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Adjust end date if needed
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
      _checkForChanges();
    }
  }

  bool _requiresRegeneration() {
    return TripEditController.requiresRegeneration(
      originalData: widget.tripData,
      newCity: _city,
      newCountry: _country,
      newStartDate: _startDate,
      newEndDate: _endDate,
      newBudgetLevel: _budgetLevel,
      newDestinationTypes: _destinationTypes,
    );
  }

  void _saveChanges() {
    if (_tripNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a trip name')),
      );
      return;
    }

    if (_city.isEmpty || _country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select travel dates')),
      );
      return;
    }

    // Check if regeneration is needed
    if (_requiresRegeneration()) {
      _confirmRegeneration();
    } else {
      // Just update metadata
      _editController.updateTripMetadata(
        tripId: widget.tripId,
        tripName: _tripNameController.text,
      ).then((success) {
        if (success && mounted) {
          Navigator.pop(context, true);
        }
      });
    }
  }

  void _confirmRegeneration() {
    final changes = TripEditController.getEditSummary(
      originalData: widget.tripData,
      newCity: _city,
      newCountry: _country,
      newStartDate: _startDate,
      newEndDate: _endDate,
      newBudgetLevel: _budgetLevel,
      newDestinationTypes: _destinationTypes,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Itinerary?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following changes will regenerate your itinerary:'),
            const SizedBox(height: 16),
            ...changes.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.arrow_forward, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey[800], fontSize: 14),
                        children: [
                          TextSpan(
                            text: '${e.key}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: e.value),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your current itinerary will be deleted and replaced.',
                      style: TextStyle(fontSize: 12, color: Colors.red[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startRegeneration();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3)),
            child: const Text('Regenerate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startRegeneration() {
    setState(() => _isRegenerating = true);

    _editController.updateTripWithRegeneration(
      tripId: widget.tripId,
      city: _city,
      country: _country,
      startDate: _startDate,
      endDate: _endDate,
      budgetLevel: _budgetLevel,
      destinationTypes: _destinationTypes,
      halalOnly: _halalOnly,
    );
  }
}

class _AnimatedRegeneratingIcon extends StatefulWidget {
  const _AnimatedRegeneratingIcon();

  @override
  State<_AnimatedRegeneratingIcon> createState() => _AnimatedRegeneratingIconState();
}

class _AnimatedRegeneratingIconState extends State<_AnimatedRegeneratingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.refresh, size: 80, color: Color(0xFF2196F3)),
      ),
    );
  }
}