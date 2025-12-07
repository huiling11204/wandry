import 'package:flutter/material.dart';
import 'package:wandry/controller/export_controller.dart';

class ExportShareBottomSheet extends StatelessWidget {
  final String tripId;
  final ExportController exportController;

  const ExportShareBottomSheet({
    Key? key,
    required this.tripId,
    required this.exportController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.file_download, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export & Share',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Choose how you want to use your itinerary',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Export PDF Option
          _buildOption(
            context,
            icon: Icons.picture_as_pdf,
            iconColor: Colors.red[600]!,
            iconBg: Colors.red[50]!,
            title: 'Export as PDF',
            subtitle: 'Save itinerary to your device',
            onTap: () {
              Navigator.pop(context);
              exportController.exportToPdf(tripId, context);
            },
          ),

          const Divider(height: 1, indent: 80),

          // Share PDF Option
          _buildOption(
            context,
            icon: Icons.share,
            iconColor: Colors.blue[600]!,
            iconBg: Colors.blue[50]!,
            title: 'Share PDF',
            subtitle: 'Share itinerary with others',
            onTap: () {
              Navigator.pop(context);
              exportController.sharePdfItinerary(tripId, context);
            },
          ),

          const Divider(height: 1, indent: 80),

          // Share as Text Option
          _buildOption(
            context,
            icon: Icons.text_fields,
            iconColor: Colors.green[600]!,
            iconBg: Colors.green[50]!,
            title: 'Share as Text',
            subtitle: 'Share simple text version',
            onTap: () {
              Navigator.pop(context);
              exportController.shareTextItinerary(tripId, context);
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, {
        required IconData icon,
        required Color iconColor,
        required Color iconBg,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// Show this bottom sheet from your trip detail page
  static void show(BuildContext context, String tripId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ExportShareBottomSheet(
        tripId: tripId,
        exportController: ExportController(),
      ),
    );
  }
}

class ExportButton extends StatelessWidget {
  final String tripId;

  const ExportButton({Key? key, required this.tripId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        ExportShareBottomSheet.show(context, tripId);
      },
      icon: const Icon(Icons.file_download),
      label: const Text('Export'),
      backgroundColor: Colors.blue[600],
    );
  }
}

class ExportIconButton extends StatelessWidget {
  final String tripId;

  const ExportIconButton({Key? key, required this.tripId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      tooltip: 'Export & Share',
      onPressed: () {
        ExportShareBottomSheet.show(context, tripId);
      },
    );
  }
}

class ExportCard extends StatelessWidget {
  final String tripId;

  const ExportCard({Key? key, required this.tripId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          ExportShareBottomSheet.show(context, tripId);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[50]!, Colors.blue[100]!],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.file_download, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Your Itinerary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Save as PDF or share with others',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.blue[600]),
            ],
          ),
        ),
      ),
    );
  }
}