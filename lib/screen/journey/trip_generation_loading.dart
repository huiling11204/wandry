import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trip_detail_page.dart';

class TripGenerationLoading extends StatefulWidget {
  final String tripName;
  final String tripDescription;
  final String destination;
  final String city;
  final String country;
  final DateTime startDate;
  final DateTime endDate;
  final String budgetLevel;
  final Map<String, dynamic>? destinationData;

  const TripGenerationLoading({
    super.key,
    required this.tripName,
    required this.tripDescription,
    required this.destination,
    required this.city,
    required this.country,
    required this.startDate,
    required this.endDate,
    required this.budgetLevel,
    this.destinationData,
  });

  @override
  State<TripGenerationLoading> createState() => _TripGenerationLoadingState();
}

class _TripGenerationLoadingState extends State<TripGenerationLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _currentStep = 0;
  String? _errorMessage;

  final List<String> _steps = [
    'Analyzing preferences...',
    'Finding best attractions...',
    'Optimizing routes...',
    'Checking weather...',
    'Creating itinerary...',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _generateTrip();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateTrip() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Step 1: Analyzing preferences
      setState(() => _currentStep = 0);
      await Future.delayed(const Duration(seconds: 1));

      // Step 2: Finding attractions (simulate)
      setState(() => _currentStep = 1);
      await Future.delayed(const Duration(seconds: 1));

      // Step 3: Optimizing routes (simulate)
      setState(() => _currentStep = 2);
      await Future.delayed(const Duration(seconds: 1));

      // Step 4: Checking weather (simulate)
      setState(() => _currentStep = 3);
      await Future.delayed(const Duration(seconds: 1));

      // Step 5: Creating itinerary
      setState(() => _currentStep = 4);

      // FIXED: Changed collection name from 'trips' to 'trip'
      // FIXED: Using consistent field names
      final tripRef = FirebaseFirestore.instance.collection('trip').doc();

      // Calculate estimated budget range based on budget level
      String estimatedBudget = _calculateBudgetRange(widget.budgetLevel);

      await tripRef.set({
        'tripID': tripRef.id,
        'userID': user.uid,
        'tripName': widget.tripName,
        'tripDescription': widget.tripDescription,
        'destination': widget.destination, // Full destination string
        'destinationCity': widget.city,
        'destinationCountry': widget.country,
        'startDate': Timestamp.fromDate(widget.startDate),
        'endDate': Timestamp.fromDate(widget.endDate),
        'budgetLevel': widget.budgetLevel, // Low, Medium, High
        'estimatedBudget': estimatedBudget, // e.g., "\$500-1000"
        'createdAt': FieldValue.serverTimestamp(), // ✓ FIXED: Using 'createdAt' consistently
        'lastUpdatedDate': FieldValue.serverTimestamp(),
        'status': 'active', // active, completed, cancelled
      });

      print('✓ Trip created successfully: ${tripRef.id}');

      // TODO: In Phase 3, this is where you'll call the ML Cloud Function:
      // final result = await functions.httpsCallable('generateCompleteTrip').call({
      //   'tripID': tripRef.id,
      //   'tripName': widget.tripName,
      //   'destination': widget.destination,
      //   'city': widget.city,
      //   'country': widget.country,
      //   'startDate': widget.startDate.toIso8601String(),
      //   'endDate': widget.endDate.toIso8601String(),
      //   'budgetLevel': widget.budgetLevel,
      //   'userID': user.uid,
      // });

      // NEW WAY (in _generateTrip)
      print('Calling ML Cloud Function...');
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('py-generateCompleteTrip').call({
        'tripID': tripRef.id,
        'userID': user.uid,
        'city': widget.city,
        'country': widget.country,
        'startDate': widget.startDate.toIso8601String(),
        'endDate': widget.endDate.toIso8601String(),
        'budgetLevel': widget.budgetLevel,
      });

      print('✅ ML function completed: ${result.data}');
      print('✓ Checking for itinerary items...');

      final itemsCheck = await FirebaseFirestore.instance
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripRef.id)
          .get();

      print('✅ Found ${itemsCheck.docs.length} itinerary items created by ML');
      if (itemsCheck.docs.isEmpty) {
        print('❌ WARNING: No itinerary items were created by the ML function!');
      }

      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to trip detail page
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => TripDetailPage(tripId: tripRef.id),
          ),
              (route) => route.isFirst, // Remove all routes except home
        );
      }
    } catch (e) {
      print('❌ Error generating trip: $e');
      setState(() {
        _errorMessage = 'Failed to generate trip. Please try again.\n\nError: ${e.toString()}';
      });
    }
  }

  String _calculateBudgetRange(String budgetLevel) {
    // Calculate per day budget estimate
    final days = widget.endDate.difference(widget.startDate).inDays + 1;

    int minPerDay, maxPerDay;
    switch (budgetLevel) {
      case 'Low':
        minPerDay = 30;
        maxPerDay = 60;
        break;
      case 'High':
        minPerDay = 150;
        maxPerDay = 300;
        break;
      default: // Medium
        minPerDay = 70;
        maxPerDay = 140;
    }

    final minTotal = minPerDay * days;
    final maxTotal = maxPerDay * days;

    return '\$$minTotal-$maxTotal';
  }

  Future<void> _createSampleItinerary(String tripId) async {
    // This is a placeholder. In Phase 3, the ML model will generate this
    final startDate = widget.startDate;
    final endDate = widget.endDate;
    final duration = endDate.difference(startDate).inDays + 1;

    // Create sample itinerary items for each day
    final batch = FirebaseFirestore.instance.batch();

    for (int day = 1; day <= duration; day++) {
      print('🔵 Creating items for day $day');
      // Morning activity
      final morningRef = FirebaseFirestore.instance.collection('itineraryItem').doc();
      batch.set(morningRef, {
        'itineraryItemID': morningRef.id,
        'tripID': tripId,
        'dayNumber': day,
        'startTime': '09:00',
        'endTime': '12:00',
        'orderInDay': 0,
        'title': 'Morning Exploration',
        'notes': 'Sample morning activity - ML recommendations will replace this in Phase 3',
        'locationID': null, // Will be populated by ML in Phase 3
        'activityID': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Afternoon activity
      final afternoonRef = FirebaseFirestore.instance.collection('itineraryItem').doc();
      batch.set(afternoonRef, {
        'itineraryItemID': afternoonRef.id,
        'tripID': tripId,
        'dayNumber': day,
        'startTime': '14:00',
        'endTime': '17:00',
        'orderInDay': 1,
        'title': 'Afternoon Adventure',
        'notes': 'Sample afternoon activity - ML recommendations will replace this in Phase 3',
        'locationID': null,
        'activityID': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Evening activity
      final eveningRef = FirebaseFirestore.instance.collection('itineraryItem').doc();
      batch.set(eveningRef, {
        'itineraryItemID': eveningRef.id,
        'tripID': tripId,
        'dayNumber': day,
        'startTime': '19:00',
        'endTime': '21:00',
        'orderInDay': 2,
        'title': 'Evening Dining',
        'notes': 'Sample evening activity - ML recommendations will replace this in Phase 3',
        'locationID': null,
        'activityID': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    print('✅ Sample itinerary batch committed successfully');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _errorMessage != null, // Allow back only on error
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_errorMessage == null) ...[
                    // Animated logo/icon
                    RotationTransition(
                      turns: _animationController,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 80,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Title
                    const Text(
                      'Creating Your Perfect Trip',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Current step
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _steps[_currentStep],
                        key: ValueKey<int>(_currentStep),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Progress indicator
                    LinearProgressIndicator(
                      value: (_currentStep + 1) / _steps.length,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                    ),
                    const SizedBox(height: 16),

                    // Progress text
                    Text(
                      '${_currentStep + 1} of ${_steps.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Steps checklist
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: List.generate(_steps.length, (index) {
                          final isComplete = index < _currentStep;
                          final isCurrent = index == _currentStep;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isComplete
                                        ? Colors.green
                                        : isCurrent
                                        ? const Color(0xFF2196F3)
                                        : Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isComplete ? Icons.check : Icons.circle,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _steps[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isComplete || isCurrent
                                          ? Colors.black87
                                          : Colors.grey[500],
                                      fontWeight: isCurrent
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ] else ...[
                    // Error state
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Oops!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Go Back',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                              _currentStep = 0;
                            });
                            _generateTrip();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Try Again',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}