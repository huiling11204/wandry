// Book tours, flights, transportation, apps

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../controller/insights_controller.dart';
import 'sweet_alert_dialog.dart';

class InsightsAnalyticsTab extends StatefulWidget {
  final String tripId;
  final String destinationCity;
  final String destinationCountry;
  final DateTime startDate;
  final DateTime endDate;

  const InsightsAnalyticsTab({
    super.key,
    required this.tripId,
    required this.destinationCity,
    required this.destinationCountry,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<InsightsAnalyticsTab> createState() => _InsightsAnalyticsTabState();
}

class _InsightsAnalyticsTabState extends State<InsightsAnalyticsTab> {
  final InsightsController _controller = InsightsController();
  late BookingLinks _bookingLinks;
  late List<UsefulApp> _usefulApps;

  @override
  void initState() {
    super.initState();
    _bookingLinks = _controller.generateBookingLinks(
      city: widget.destinationCity,
      country: widget.destinationCountry,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
    _usefulApps = _controller.getUsefulApps(widget.destinationCountry);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        _buildHeader(),
        const SizedBox(height: 20),

        // Tours & Activities
        _buildToursSection(),
        const SizedBox(height: 20),

        // Flights
        _buildFlightsSection(),
        const SizedBox(height: 20),

        // Transportation
        _buildTransportationSection(),
        const SizedBox(height: 20),

        // Car Rental
        _buildCarRentalSection(),
        const SizedBox(height: 20),

        // Useful Apps
        _buildUsefulAppsSection(),
        const SizedBox(height: 20),

        // Maps
        _buildMapsSection(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[400]!, Colors.teal[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Insights & Book',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart links for ${widget.destinationCity}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.9), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap any card to open the booking website',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 13,
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

  Widget _buildToursSection() {
    return _buildSection(
      title: 'Tours & Activities',
      icon: Icons.local_activity,
      color: Colors.orange,
      children: [
        _buildBookingCard(
          name: 'Viator',
          description: 'Tours, tickets & experiences',
          icon: '🎫',
          url: _bookingLinks.viator,
          color: Colors.orange,
        ),
        _buildBookingCard(
          name: 'GetYourGuide',
          description: 'Local tours & activities',
          icon: '🗺️',
          url: _bookingLinks.getYourGuide,
          color: Colors.blue,
        ),
        _buildBookingCard(
          name: 'Klook',
          description: 'Asian tours & discounts',
          icon: '🎟️',
          url: _bookingLinks.klook,
          color: Colors.orange[800]!,
        ),
      ],
    );
  }

  Widget _buildFlightsSection() {
    return _buildSection(
      title: 'Flights',
      icon: Icons.flight,
      color: Colors.blue,
      children: [
        _buildBookingCard(
          name: 'Google Flights',
          description: 'Compare flight prices',
          icon: '✈️',
          url: _bookingLinks.googleFlights,
          color: Colors.blue,
        ),
        _buildBookingCard(
          name: 'Skyscanner',
          description: 'Find cheapest flights',
          icon: '🛫',
          url: _bookingLinks.skyscanner,
          color: Colors.cyan,
        ),
        _buildBookingCard(
          name: 'Kayak',
          description: 'Compare all airlines',
          icon: '🔍',
          url: _bookingLinks.kayak,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildTransportationSection() {
    return _buildSection(
      title: 'Transportation',
      icon: Icons.directions_bus,
      color: Colors.green,
      children: [
        _buildBookingCard(
          name: 'Rome2Rio',
          description: 'All transport options',
          icon: '🚌',
          url: _bookingLinks.rome2rio,
          color: Colors.green,
        ),
        _buildBookingCard(
          name: 'Grab',
          description: 'Rides & delivery (Asia)',
          icon: '🚗',
          url: _bookingLinks.grab,
          color: Colors.green[700]!,
        ),
        _buildBookingCard(
          name: 'Uber',
          description: 'Rides worldwide',
          icon: '🚕',
          url: _bookingLinks.uber,
          color: Colors.black87,
        ),
      ],
    );
  }

  Widget _buildCarRentalSection() {
    return _buildSection(
      title: 'Car Rental',
      icon: Icons.car_rental,
      color: Colors.purple,
      children: [
        _buildBookingCard(
          name: 'RentalCars',
          description: 'Compare car rentals',
          icon: '🚙',
          url: _bookingLinks.rentalCars,
          color: Colors.purple,
        ),
        _buildBookingCard(
          name: 'Kayak Cars',
          description: 'Best car deals',
          icon: '🚘',
          url: _bookingLinks.kayakCars,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildUsefulAppsSection() {
    return _buildSection(
      title: 'Useful Apps',
      icon: Icons.apps,
      color: Colors.teal,
      children: _usefulApps.map((app) => _buildAppCard(app)).toList(),
    );
  }

  Widget _buildMapsSection() {
    return _buildSection(
      title: 'Maps & Navigation',
      icon: Icons.map,
      color: Colors.red,
      children: [
        _buildBookingCard(
          name: 'Google Maps',
          description: 'Navigate ${widget.destinationCity}',
          icon: '📍',
          url: _bookingLinks.googleMaps,
          color: Colors.red,
        ),
        _buildBookingCard(
          name: 'Offline Map',
          description: 'Download for offline use',
          icon: '📲',
          url: _bookingLinks.offlineMap,
          color: Colors.blue[700]!,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard({
    required String name,
    required String description,
    required String icon,
    required String url,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showExternalLinkDialog(name, url),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  color: color,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard(UsefulApp app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAppStoreDialog(app),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    app.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, color: Colors.teal[700], size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Get',
                        style: TextStyle(
                          color: Colors.teal[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show confirmation dialog before opening external link
  Future<void> _showExternalLinkDialog(String siteName, String url) async {
    final result = await SweetAlertDialog.show(
      context: context,
      type: SweetAlertType.info,
      title: 'Leaving Wandry',
      subtitle: 'You are about to visit $siteName. This will open in your browser.',
      content: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.link, color: Colors.grey[600], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getShortenedUrl(url),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      confirmText: 'Open',
      cancelText: 'Cancel',
      showCancelButton: true,
    );

    if (result == true) {
      _launchUrl(url);
    }
  }

  /// Show confirmation dialog before opening app store
  Future<void> _showAppStoreDialog(UsefulApp app) async {
    final storeName = Platform.isIOS ? 'App Store' : 'Play Store';

    final result = await SweetAlertDialog.show(
      context: context,
      type: SweetAlertType.info,
      title: 'Open $storeName',
      subtitle: 'You are about to download "${app.name}" from the $storeName.',
      content: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Text(app.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    app.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      confirmText: 'Download',
      cancelText: 'Cancel',
      showCancelButton: true,
    );

    if (result == true) {
      _launchAppStore(app);
    }
  }

  /// Get shortened URL for display
  String _getShortenedUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host + (uri.path.length > 20 ? uri.path.substring(0, 20) + '...' : uri.path);
    } catch (e) {
      return url.length > 40 ? '${url.substring(0, 40)}...' : url;
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Show error if cannot open
      if (mounted) {
        SweetAlertDialog.error(
          context: context,
          title: 'Cannot Open Link',
          subtitle: 'Unable to open the website. Please try again later.',
        );
      }
    }
  }

  Future<void> _launchAppStore(UsefulApp app) async {
    try {
      String url;

      // Try to detect platform
      if (Platform.isIOS) {
        url = app.iosUrl;
      } else {
        url = app.androidUrl;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Fallback to Android URL for web/unknown
      try {
        final uri = Uri.parse(app.androidUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        // Show error if cannot open
        if (mounted) {
          SweetAlertDialog.error(
            context: context,
            title: 'Cannot Open Store',
            subtitle: 'Unable to open the app store. Please try again later.',
          );
        }
      }
    }
  }
}