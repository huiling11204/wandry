import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
  StreamSubscription? _tripStatusSubscription;
  String _statusMessage = 'Initializing...';

  final List<String> _steps = [
    'Creating trip...',
    'Analyzing destination...',
    'Finding attractions...',
    'Building itinerary...',
    'Finalizing details...',
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
    _tripStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _generateTrip() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      setState(() {
        _currentStep = 0;
        _statusMessage = 'Creating your trip...';
      });

      final tripRef = FirebaseFirestore.instance.collection('trip').doc();
      String estimatedBudget = _calculateBudgetRange(widget.budgetLevel);

      await tripRef.set({
        'tripID': tripRef.id,
        'userID': user.uid,
        'tripName': widget.tripName,
        'tripDescription': widget.tripDescription,
        'destination': widget.destination,
        'destinationCity': widget.city,
        'destinationCountry': widget.country,
        'startDate': Timestamp.fromDate(widget.startDate),
        'endDate': Timestamp.fromDate(widget.endDate),
        'budgetLevel': widget.budgetLevel,
        'estimatedBudget': estimatedBudget,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdatedDate': FieldValue.serverTimestamp(),
        'status': 'active',
        'generationStatus': 'pending',
      });

      print('✓ Trip created successfully: ${tripRef.id}');
      _listenToTripStatus(tripRef.id);

      setState(() {
        _currentStep = 1;
        _statusMessage = 'Starting trip generation...';
      });

      final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

      print('Calling ML Cloud Function...');
      final result = await functions.httpsCallable('py-generateCompleteTrip').call({
        'tripID': tripRef.id,
        'userID': user.uid,
        'city': widget.city,
        'country': widget.country,
        'startDate': widget.startDate.toIso8601String(),
        'endDate': widget.endDate.toIso8601String(),
        'budgetLevel': widget.budgetLevel,
      });

      print('✅ Function called: ${result.data}');

      setState(() {
        _currentStep = 2;
        _statusMessage = 'Processing in background...';
      });

    } catch (e) {
      print('❌ Error generating trip: $e');
      setState(() {
        _errorMessage = 'Failed to generate trip. Please try again.\n\nError: ${e.toString()}';
      });
      _tripStatusSubscription?.cancel();
    }
  }

  void _listenToTripStatus(String tripId) {
    print('👂 Listening to trip status for: $tripId');

    _tripStatusSubscription = FirebaseFirestore.instance
        .collection('trip')
        .doc(tripId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final generationStatus = data['generationStatus'] as String?;
      print('📊 Status update: $generationStatus');

      setState(() {
        switch (generationStatus) {
          case 'pending':
            _currentStep = 1;
            _statusMessage = 'Waiting to start...';
            break;

          case 'processing':
            _currentStep = 3;
            _statusMessage = 'Generating your perfect itinerary...';
            break;

          case 'completed':
            _currentStep = 4;
            _statusMessage = 'Trip ready!';
            _onTripCompleted(tripId);
            break;

          case 'failed':
            final error = data['generationError'] as String? ?? 'Unknown error';
            _errorMessage = 'Generation failed: $error';
            _tripStatusSubscription?.cancel();
            break;
        }
      });
    }, onError: (error) {
      print('❌ Listener error: $error');
      setState(() {
        _errorMessage = 'Connection error: ${error.toString()}';
      });
    });
  }

  Future<void> _onTripCompleted(String tripId) async {
    print('✅ Trip generation completed!');
    await Future.delayed(const Duration(milliseconds: 800));
    _tripStatusSubscription?.cancel();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => TripDetailPage(tripId: tripId),
        ),
            (route) => route.isFirst,
      );
    }
  }

  String _calculateBudgetRange(String budgetLevel) {
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
      default:
        minPerDay = 70;
        maxPerDay = 140;
    }

    final minTotal = minPerDay * days;
    final maxTotal = maxPerDay * days;

    return '\$$minTotal-$maxTotal';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _errorMessage != null,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
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
                    const SizedBox(height: 32),

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
                    const SizedBox(height: 12),

                    // Current status message
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _statusMessage,
                        key: ValueKey<String>(_statusMessage),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress indicator
                    LinearProgressIndicator(
                      value: (_currentStep + 1) / _steps.length,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                    ),
                    const SizedBox(height: 12),

                    // Progress text
                    Text(
                      '${_currentStep + 1} of ${_steps.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Steps checklist
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: List.generate(_steps.length, (index) {
                          final isComplete = index < _currentStep;
                          final isCurrent = index == _currentStep;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
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
                    const SizedBox(height: 20),

                    // Helpful message
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2196F3).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: const Color(0xFF2196F3),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This may take 30-60 seconds. Feel free to wait or come back later!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
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