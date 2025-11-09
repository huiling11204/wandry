import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:wandry/screen/nearby_attractions_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with WidgetsBindingObserver {
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationError;
  String _currentAddress = 'Fetching address...';
  Timer? _permissionCheckTimer;
  bool _isCheckingPermissions = false;
  bool _wasPermissionDeniedForever = false; // NEW: Track if we need to request permission

  // Search parameters with more options
  double _searchRadius = 1.0; // in kilometers
  final List<double> _radiusOptions = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionCheckTimer?.cancel();
    super.dispose();
  }

  // Detect when app resumes from background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Small delay to ensure permissions are updated
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _locationError != null) {
          _checkAndRetryLocation();
        }
      });
    }
  }

  // Start periodic permission checking when user goes to settings
  void _startPermissionChecking() {
    _permissionCheckTimer?.cancel();

    print('Starting permission checking timer...');

    setState(() {
      _isCheckingPermissions = true;
      _wasPermissionDeniedForever = true; // Remember we need to request permission
      _locationError = null; // Clear error while checking
    });

    // Check every 2 seconds for up to 2 minutes
    int checkCount = 0;
    _permissionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      checkCount++;
      print('Permission check #$checkCount');

      // Stop after 60 checks (2 minutes)
      if (checkCount > 60 || !mounted) {
        print('Stopping permission checks (timeout or widget disposed)');
        timer.cancel();
        if (mounted) {
          setState(() {
            _isCheckingPermissions = false;
            _wasPermissionDeniedForever = false;
            // Restore error if location still not available
            if (_currentPosition == null) {
              _locationError = 'Location permissions are permanently denied. Please enable them in app settings.';
            }
          });
        }
        return;
      }

      await _checkAndRetryLocation();

      // If location is retrieved successfully, stop checking
      if (_currentPosition != null || _isLoadingLocation) {
        print('Stopping permission checks (location obtained or loading)');
        timer.cancel();
        if (mounted) {
          setState(() {
            _isCheckingPermissions = false;
            _wasPermissionDeniedForever = false;
          });
        }
      }
    });
  }

  // Check if permissions are now granted and retry
  Future<void> _checkAndRetryLocation() async {
    if (_isLoadingLocation) return; // Don't check if already loading

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      print('Checking permission status: $permission');

      // If permission is now granted, retry getting location
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (_locationError != null || _currentPosition == null) {
          print('Permission granted! Retrying location...');
          await _getCurrentLocation();

          // Show success notification if location is now available
          if (mounted && _currentPosition != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Location accessed successfully!'),
                  ],
                ),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
      // NEW: If permission changed from deniedForever to denied (Ask every time)
      // we need to request permission again
      else if (permission == LocationPermission.denied && _wasPermissionDeniedForever) {
        print('Permission is now askable! Requesting permission...');

        // Request permission (will show dialog to user)
        LocationPermission newPermission = await Geolocator.requestPermission();
        print('Permission after request: $newPermission');

        if (newPermission == LocationPermission.whileInUse ||
            newPermission == LocationPermission.always) {
          print('User granted permission! Getting location...');
          await _getCurrentLocation();

          // Show success notification
          if (mounted && _currentPosition != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Location accessed successfully!'),
                  ],
                ),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error checking permission: $e');
    }
  }

  // IMPROVED: Get current location with better permission handling
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them in your device settings.');
      }

      // Check for permissions
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please allow location access to use this feature.');
        }
      }

      // IMPROVED: Handle permanently denied permissions
      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
        throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Get address from coordinates
      _getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _locationError = e.toString();
        _isLoadingLocation = false;
        _currentAddress = 'Unable to fetch address';
      });
    }
  }

  // NEW: Show dialog when permissions are permanently denied
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_off,
                color: Colors.red[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Location Permission Required',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location access has been permanently denied. To use this feature, you need to:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildPermissionStep('1', 'Open App Settings'),
              _buildPermissionStep('2', 'Find "Permissions" or "Location"'),
              _buildPermissionStep('3', 'Enable Location Access'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'The app will automatically detect when you return and retry',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                // Start checking for permission changes
                _startPermissionChecking();
                // Show notification
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Waiting for you to enable location...'),
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 5),
                    backgroundColor: const Color(0xFF4A90E2),
                  ),
                );
                // Open app settings
                await Geolocator.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Get address from coordinates
  Future<void> _getAddressFromCoordinates(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress = '${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'Address unavailable';
      });
    }
  }

  // Navigate to Nearby Attractions Page
  void _navigateToNearbyAttractions() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NearbyAttractionsPage(
          currentPosition: _currentPosition!,
          searchRadius: _searchRadius,
        ),
      ),
    );
  }

  String _formatRadius(double radius) {
    if (radius < 1) {
      return '${(radius * 1000).toInt()}m';
    } else {
      return '${radius.toStringAsFixed(radius >= 10 ? 0 : 1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Explore',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover amazing places around you',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 32),

                // Current Location Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A90E2).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Your Current Location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (!_isLoadingLocation && _currentPosition != null)
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              onPressed: _getCurrentLocation,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingLocation)
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Getting your location...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      else if (_isCheckingPermissions)
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Checking for permission...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (_currentPosition != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.place,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _currentAddress,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_locationError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Location unavailable',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Search Radius Section
                const Text(
                  'Search Radius',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButton<double>(
                    value: _searchRadius,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.expand_more, color: Color(0xFF4A90E2)),
                    items: _radiusOptions.map((radius) {
                      return DropdownMenuItem(
                        value: radius,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A90E2).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatRadius(radius),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A90E2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Search within ${_formatRadius(radius)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _searchRadius = value!;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 40),

                // Quick Stats
                if (_currentPosition != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Icons.explore,
                          'Ready',
                          'to Explore',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey[300],
                        ),
                        _buildStatItem(
                          Icons.radar,
                          _formatRadius(_searchRadius),
                          'Search Area',
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Error Display with Settings Button
                if (_locationError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location Error',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _locationError!,
                                    style: TextStyle(
                                      color: Colors.red[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_locationError!.contains('permanently denied'))
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  // Start checking for permission changes
                                  _startPermissionChecking();
                                  // Show notification
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text('Waiting for you to enable location...'),
                                          ),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 5),
                                      backgroundColor: const Color(0xFF4A90E2),
                                    ),
                                  );
                                  await Geolocator.openAppSettings();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.settings, size: 18),
                                label: const Text('Open Settings'),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _getCurrentLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Try Again'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Find Nearby Attractions Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _currentPosition != null && !_isLoadingLocation
                        ? _navigateToNearbyAttractions
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[300],
                      shadowColor: const Color(0xFF4A90E2).withOpacity(0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search, size: 22),
                        const SizedBox(width: 12),
                        const Text(
                          'Find Nearby Attractions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4A90E2), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}