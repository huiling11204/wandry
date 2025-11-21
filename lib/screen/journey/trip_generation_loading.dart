import 'package:flutter/material.dart';
import 'package:wandry/controller/trip_generation_controller.dart';
import 'package:wandry/widget/generation_progress_widget.dart';
import 'trip_detail_page.dart';

class TripGenerationLoadingPage extends StatefulWidget {
  final String tripName;
  final String tripDescription;
  final String destination;
  final String city;
  final String country;
  final DateTime startDate;
  final DateTime endDate;
  final String budgetLevel;
  final Map<String, dynamic>? destinationData;

  const TripGenerationLoadingPage({
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
  State<TripGenerationLoadingPage> createState() => _TripGenerationLoadingPageState();
}

class _TripGenerationLoadingPageState extends State<TripGenerationLoadingPage> {
  late TripGenerationController _controller;
  int _currentStep = 0;
  String _statusMessage = 'Initializing...';
  String? _errorMessage;

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
    _controller = TripGenerationController();
    _setupController();
    _generateTrip();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setupController() {
    _controller.onStatusUpdate = (step, message) {
      if (mounted) {
        setState(() {
          _currentStep = step;
          _statusMessage = message;
        });
      }
    };

    _controller.onCompleted = (tripId) async {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => TripDetailPage(tripId: tripId),
          ),
              (route) => route.isFirst,
        );
      }
    };

    _controller.onError = (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
        });
      }
    };
  }

  Future<void> _generateTrip() async {
    await _controller.generateTrip(
      tripName: widget.tripName,
      tripDescription: widget.tripDescription,
      destination: widget.destination,
      city: widget.city,
      country: widget.country,
      startDate: widget.startDate,
      endDate: widget.endDate,
      budgetLevel: widget.budgetLevel,
    );
  }

  void _retryGeneration() {
    setState(() {
      _errorMessage = null;
      _currentStep = 0;
      _statusMessage = 'Initializing...';
    });
    _generateTrip();
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
                    // Animated loading icon
                    const AnimatedLoadingIcon(),
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
                    GenerationProgressWidget(
                      currentStep: _currentStep,
                      steps: _steps,
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
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF2196F3),
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
                          onPressed: () => Navigator.of(context).pop(),
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
                          onPressed: _retryGeneration,
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