import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wandry/controller/trip_generation_controller.dart';
import 'package:wandry/widget/destination_type_selector_widget.dart';
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
  final List<String> destinationTypes;

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
    this.destinationTypes = const ['relaxing'],
  });

  @override
  State<TripGenerationLoadingPage> createState() => _TripGenerationLoadingPageState();
}

class _TripGenerationLoadingPageState extends State<TripGenerationLoadingPage> {
  TripGenerationController? _controller;
  int _progress = 0;
  int _highestProgress = 0;
  String? _errorCode;
  String? _errorMessage;
  String? _warningMessage;
  bool _warningShown = false;
  String? _currentTripId;
  bool _showCancelOption = false;
  bool _isNavigating = false;

  DateTime _lastUpdateTime = DateTime.now();
  static const _minUpdateInterval = Duration(milliseconds: 500);

  // Progress steps with ranges
  static const List<Map<String, dynamic>> _steps = [
    {'name': 'Finding location', 'min': 0, 'max': 10},
    {'name': 'Getting weather', 'min': 10, 'max': 20},
    {'name': 'Finding hotels', 'min': 20, 'max': 35},
    {'name': 'Finding attractions', 'min': 35, 'max': 50},
    {'name': 'Finding restaurants', 'min': 50, 'max': 70},
    {'name': 'Building itinerary', 'min': 70, 'max': 85},
    {'name': 'Saving trip', 'min': 85, 'max': 100},
  ];

  // Derive current status from progress
  String get _currentStatusMessage {
    for (var step in _steps) {
      final min = step['min'] as int;
      final max = step['max'] as int;
      if (_highestProgress >= min && _highestProgress < max) {
        return '${step['name']}...';
      }
    }
    if (_highestProgress >= 100) {
      return 'Completing...';
    }
    return 'Initializing...';
  }

  @override
  void initState() {
    super.initState();
    _startGeneration();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _setupController() {
    _controller?.dispose();
    _controller = TripGenerationController();

    _controller!.onProgressUpdate = (progress, message) {
      if (!mounted || _isNavigating) return;

      final now = DateTime.now();
      if (now.difference(_lastUpdateTime) < _minUpdateInterval && progress <= _highestProgress) {
        return;
      }
      _lastUpdateTime = now;

      if (progress > _highestProgress) {
        setState(() {
          _highestProgress = progress;
          _progress = progress;
        });
      }
    };

    _controller!.onWarning = (warning) {
      if (!mounted || _warningShown || _isNavigating) return;

      setState(() {
        _warningMessage = warning;
        _warningShown = true;
        _showCancelOption = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isNavigating) {
          _showWarningDialog(warning);
        }
      });
    };

    _controller!.onCompleted = (tripId, warning, dataQuality) {
      if (!mounted || _isNavigating) return;
      if (_currentTripId != null && tripId != _currentTripId) return;

      _isNavigating = true;

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;

        if (dataQuality == 'limited') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Trip created with limited data.'),
              backgroundColor: Colors.orange[700],
              duration: const Duration(seconds: 3),
            ),
          );
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => TripDetailPage(tripId: tripId)),
              (route) => route.isFirst,
        );
      });
    };

    _controller!.onError = (errorCode, errorMessage) {
      if (!mounted || _isNavigating) return;

      setState(() {
        _errorCode = errorCode;
        _errorMessage = errorMessage;
      });

      // Delete the failed trip
      if (_currentTripId != null) {
        _deleteFailedTrip(_currentTripId!);
      }
    };
  }

  Future<void> _deleteFailedTrip(String tripId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Delete itinerary items (if any)
      final items = await firestore
          .collection('itineraryItem')
          .where('tripID', isEqualTo: tripId)
          .get();

      final batch = firestore.batch();
      for (var doc in items.docs) {
        batch.delete(doc.reference);
      }

      // Delete the trip
      batch.delete(firestore.collection('trip').doc(tripId));

      await batch.commit();
      print('🗑️ Deleted failed trip: $tripId');
    } catch (e) {
      print('Failed to delete trip: $e');
    }
  }

  void _showWarningDialog(String warning) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Large City Detected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(warning, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Generation may fail. You can continue or go back.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _cancelAndDeleteTrip();
            },
            child: Text('Go Back', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Continue Anyway', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _cancelAndDeleteTrip() {
    if (_isNavigating) return;
    _isNavigating = true;

    // Delete the trip that was created
    if (_currentTripId != null) {
      _deleteFailedTrip(_currentTripId!);
    }

    _controller?.dispose();
    _controller = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _safeGoBack() {
    if (_isNavigating) return;
    _isNavigating = true;

    _controller?.dispose();
    _controller = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _startGeneration() async {
    _setupController();

    final tripId = await _controller!.generateTrip(
      tripName: widget.tripName,
      tripDescription: widget.tripDescription,
      destination: widget.destination,
      city: widget.city,
      country: widget.country,
      startDate: widget.startDate,
      endDate: widget.endDate,
      budgetLevel: widget.budgetLevel,
      destinationTypes: widget.destinationTypes,
    );

    if (tripId != null && mounted) {
      setState(() {
        _currentTripId = tripId;
      });
    }
  }

  void _retryGeneration() {
    if (_isNavigating) return;

    // IMPORTANT: Fully dispose and null out controller
    _controller?.dispose();
    _controller = null;

    // Reset ALL state
    setState(() {
      _errorCode = null;
      _errorMessage = null;
      _progress = 0;
      _highestProgress = 0;
      _warningShown = false;
      _warningMessage = null;
      _currentTripId = null;
      _showCancelOption = false;
      _isNavigating = false;
      _lastUpdateTime = DateTime.now();
    });

    // Start fresh after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startGeneration();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _errorCode != null || _showCancelOption,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showCancelOption && !_isNavigating) {
          _cancelAndDeleteTrip();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: _errorCode != null ? _buildErrorState() : _buildLoadingState(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _AnimatedLoadingIcon(),
        const SizedBox(height: 32),
        const Text(
          'Creating Your Perfect Trip',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.city}, ${widget.country}',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          '$_progress%',
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF2196F3)),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 16),

        // Status derived from progress (not backend)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _currentStatusMessage,
            style: const TextStyle(fontSize: 14, color: Color(0xFF2196F3), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),

        _buildProgressSteps(),
        const SizedBox(height: 20),

        if (_warningMessage != null) ...[
          _buildWarningBanner(),
          const SizedBox(height: 16),
        ],

        if (widget.destinationTypes.isNotEmpty && _warningMessage == null) ...[
          _buildStylesCard(),
          const SizedBox(height: 16),
        ],

        _buildInfoCard(),

        if (_showCancelOption) ...[
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _cancelAndDeleteTrip,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Cancel and Go Back'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressSteps() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _steps.map((step) {
          final min = step['min'] as int;
          final max = step['max'] as int;
          final name = step['name'] as String;

          final isComplete = _highestProgress >= max;
          final isCurrent = _highestProgress >= min && _highestProgress < max;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
                  child: Center(
                    child: isComplete
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : isCurrent
                        ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      color: isComplete || isCurrent ? Colors.black87 : Colors.grey[400],
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Large city - may take longer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange[800]),
                ),
                const SizedBox(height: 2),
                Text(
                  'Generation might fail. You can cancel anytime.',
                  style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStylesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(Icons.auto_awesome, color: Colors.green[700], size: 18),
              const SizedBox(width: 8),
              Text(
                'Personalizing for your style:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green[700]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DestinationTypeChips(typeIds: widget.destinationTypes),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF2196F3), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This may take 30-60 seconds.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final errorInfo = GenerationErrorCodes.getErrorInfo(_errorCode ?? 'GENERATION_FAILED');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: errorInfo.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(errorInfo.icon, size: 64, color: errorInfo.color),
        ),
        const SizedBox(height: 24),
        Text(
          errorInfo.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${widget.city}, ${widget.country}',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Text(
                _errorMessage ?? 'An error occurred',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: errorInfo.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: errorInfo.color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorInfo.suggestion,
                        style: TextStyle(fontSize: 13, color: errorInfo.color, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (_errorCode == 'CITY_TOO_LARGE' || _errorCode == 'NO_DESTINATIONS' || _errorCode == 'REMOTE_AREA') ...[
          _buildRecommendedDestinations(),
          const SizedBox(height: 24),
        ],
        ElevatedButton.icon(
          onPressed: _safeGoBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Choose Different Destination', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedDestinations() {
    final recommendations = [
      {'city': 'Tokyo', 'icon': '🗼'},
      {'city': 'Bangkok', 'icon': '🛕'},
      {'city': 'Singapore', 'icon': '🏙️'},
      {'city': 'Kuala Lumpur', 'icon': '🏢'},
      {'city': 'Seoul', 'icon': '🏯'},
    ];

    return Column(
      children: [
        Text(
          'Try these popular destinations:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: recommendations.map((dest) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dest['icon']!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    dest['city']!,
                    style: TextStyle(fontSize: 13, color: Colors.blue[700], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AnimatedLoadingIcon extends StatefulWidget {
  const _AnimatedLoadingIcon();

  @override
  State<_AnimatedLoadingIcon> createState() => _AnimatedLoadingIconState();
}

class _AnimatedLoadingIconState extends State<_AnimatedLoadingIcon>
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
        child: const Icon(Icons.auto_awesome, size: 80, color: Color(0xFF2196F3)),
      ),
    );
  }
}

class GenerationErrorCodes {
  static const Map<String, ErrorInfo> errors = {
    'CITY_TOO_LARGE': ErrorInfo(
      title: 'City Too Large',
      icon: Icons.location_city,
      color: Colors.orange,
      suggestion: 'Try searching for a specific district or area instead.',
    ),
    'REMOTE_AREA': ErrorInfo(
      title: 'Remote Area',
      icon: Icons.terrain,
      color: Colors.amber,
      suggestion: 'This area has limited data. Results may be incomplete.',
    ),
    'NO_DESTINATIONS': ErrorInfo(
      title: 'No Attractions Found',
      icon: Icons.search_off,
      color: Colors.red,
      suggestion: 'Try a different destination or nearby major city.',
    ),
    'NO_RESTAURANTS': ErrorInfo(
      title: 'No Restaurants Found',
      icon: Icons.restaurant,
      color: Colors.orange,
      suggestion: 'This might be a remote location with limited dining options.',
    ),
    'GEOCODE_FAILED': ErrorInfo(
      title: 'Location Not Found',
      icon: Icons.location_off,
      color: Colors.red,
      suggestion: 'Please check the spelling or try a nearby city.',
    ),
    'API_TIMEOUT': ErrorInfo(
      title: 'Server Busy',
      icon: Icons.cloud_off,
      color: Colors.grey,
      suggestion: 'Please try again in a few minutes.',
    ),
    'GENERATION_FAILED': ErrorInfo(
      title: 'Generation Failed',
      icon: Icons.error_outline,
      color: Colors.red,
      suggestion: 'Something went wrong. Please try again.',
    ),
  };

  static ErrorInfo getErrorInfo(String code) {
    return errors[code] ?? errors['GENERATION_FAILED']!;
  }
}

class ErrorInfo {
  final String title;
  final IconData icon;
  final Color color;
  final String suggestion;

  const ErrorInfo({
    required this.title,
    required this.icon,
    required this.color,
    required this.suggestion,
  });
}