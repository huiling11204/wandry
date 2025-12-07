import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../model/trip_model.dart';

/// Exports trip itinerary as PDF or text
class ExportController{
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Exports trip to PDF and opens preview
  Future<void> exportToPdf(String tripId, BuildContext context) async {
    if (!context.mounted) return;

    BuildContext? dialogContext;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        dialogContext = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Expanded(child: Text('Generating PDF...')),
              ],
            ),
          ),
        );
      },
    );

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch all trip data
      print('📄 Fetching trip data...');
      final trip = await _fetchTripData(tripId);
      print('✅ Trip data fetched: ${trip.tripName}');

      final itinerarySnapshot = await _fetchItineraryItems(tripId);
      print('✅ Found ${itinerarySnapshot.docs.length} itinerary items');

      final accommodationDoc = await _fetchAccommodation(tripId);
      print('✅ Accommodation doc exists: ${accommodationDoc?.exists ?? false}');

      // Generate PDF with timeout
      print('📄 Generating lightweight PDF...');
      final pdfBytes = await _generatePdfBytes(
        trip,
        itinerarySnapshot.docs,
        accommodationDoc,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          print('⏱️ PDF generation timed out!');
          throw TimeoutException('PDF generation took too long');
        },
      );
      print('✅ PDF generated: ${pdfBytes.length} bytes');

      // Save to file
      final fileName = '${trip.tripName.replaceAll(' ', '_')}_Itinerary.pdf';
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      print('✅ PDF saved to: ${file.path}');

      // Close loading dialog
      print('🔧 Closing dialog...');
      final ctx = dialogContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
        print('🔧 Dialog closed');
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // Open PDF preview
      print('👁️ Opening PDF preview...');
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
        );
        print('✅ PDF preview opened successfully');

        if (context.mounted) {
          _showSuccess(context, 'PDF saved successfully!');
        }
      } catch (e, stackTrace) {
        print('❌ Error opening PDF preview: $e');
        print('Stack trace: $stackTrace');
      }
    } catch (e) {
      print('❌ Error during PDF export: $e');
      final ctx = dialogContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      }

      if (context.mounted) {
        _showError(context, 'Failed to export PDF: $e');
      }
    }
  }

  /// Shares trip as PDF file
  Future<void> sharePdfItinerary(String tripId, BuildContext context) async {
    if (!context.mounted) return;

    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        dialogContext = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Expanded(child: Text('Preparing PDF...')),
              ],
            ),
          ),
        );
      },
    );

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch data and generate PDF
      print('📤 Fetching trip data for sharing...');
      final trip = await _fetchTripData(tripId);
      final itinerarySnapshot = await _fetchItineraryItems(tripId);
      final accommodationDoc = await _fetchAccommodation(tripId);

      print('📄 Generating PDF for sharing...');
      final pdfBytes = await _generatePdfBytes(
        trip,
        itinerarySnapshot.docs,
        accommodationDoc,
      ).timeout(const Duration(seconds: 45));

      // Save to temp file
      final fileName = '${trip.tripName.replaceAll(' ', '_')}_Itinerary.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      print('✅ PDF file written to: ${file.path}');

      // Close dialog
      final ctx = dialogContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // Share file
      print('📤 Opening share dialog...');
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${trip.tripName} - Travel Itinerary',
        text: 'Check out my ${trip.tripName} travel itinerary!',
      );
    } catch (e) {
      print('❌ Error during PDF sharing: $e');
      final ctx = dialogContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      }

      if (context.mounted) {
        _showError(context, 'Failed to share: $e');
      }
    }
  }

  /// Shares trip as plain text
  Future<void> shareTextItinerary(String tripId, BuildContext context) async {
    if (!context.mounted) return;

    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        dialogContext = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                const Expanded(child: Text('Preparing itinerary...')),
              ],
            ),
          ),
        );
      },
    );

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch data
      print('📝 Fetching trip data for text export...');
      final trip = await _fetchTripData(tripId);
      final itinerarySnapshot = await _fetchItineraryItems(tripId);
      final accommodationDoc = await _fetchAccommodation(tripId);

      // Build text content
      print('📝 Building text content...');
      final textContent = _buildTextContent(
        trip,
        itinerarySnapshot.docs,
        accommodationDoc,
      );
      print('✅ Text content generated: ${textContent.length} characters');

      // Close dialog
      final ctx = dialogContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // Share text
      print('📤 Opening share dialog...');
      await Share.share(
        textContent,
        subject: '${trip.tripName} - Travel Itinerary',
      );
    } catch (e) {
      print('❌ Error during text sharing: $e');
      final ctx = dialogContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      }

      if (context.mounted) {
        _showError(context, 'Failed to share: $e');
      }
    }
  }

  /// Fetches trip document from Firestore
  Future<TripModel> _fetchTripData(String tripId) async {
    final tripDoc = await _firestore.collection('trip').doc(tripId).get();
    if (!tripDoc.exists) throw Exception('Trip not found');
    return TripModel.fromFirestore(tripDoc);
  }

  /// Fetches itinerary items sorted by day and order
  Future<QuerySnapshot> _fetchItineraryItems(String tripId) {
    return _firestore
        .collection('itineraryItem')
        .where('tripID', isEqualTo: tripId)
        .orderBy('dayNumber')
        .orderBy('orderInDay')
        .get();
  }

  /// Fetches accommodation document
  Future<DocumentSnapshot?> _fetchAccommodation(String tripId) async {
    final doc = await _firestore.collection('accommodation').doc(tripId).get();
    return doc.exists ? doc : null;
  }

  /// Generates PDF bytes from trip data
  Future<Uint8List> _generatePdfBytes(
      TripModel trip,
      List<QueryDocumentSnapshot> itineraryDocs,
      DocumentSnapshot? accommodationDoc,
      ) async {
    print('🔧 Starting PDF generation...');

    try {
      final pdf = pw.Document();

      // Load font
      print('🔧 Loading font...');
      final font = await PdfGoogleFonts.notoSansSCRegular();

      // Define colors
      final primaryColor = PdfColor.fromHex('#1E88E5');
      final accentColor = PdfColor.fromHex('#FF6F00');
      final successColor = PdfColor.fromHex('#43A047');

      // Build PDF pages
      print('🔧 Building pages...');
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            print('🔧 Building content...');
            final widgets = <pw.Widget>[];

            // Header section
            widgets.add(_buildCompactHeader(trip, primaryColor, font));
            widgets.add(pw.SizedBox(height: 16));

            // Overview section
            widgets.add(_buildCompactOverview(trip, primaryColor, accentColor, successColor, font));
            widgets.add(pw.SizedBox(height: 16));

            // Accommodations section
            if (accommodationDoc != null && accommodationDoc.exists) {
              widgets.add(_buildSectionTitle('Accommodations', font, primaryColor));
              widgets.add(pw.SizedBox(height: 8));
              widgets.addAll(_buildCompactAccommodations(accommodationDoc, font, primaryColor, successColor));
              widgets.add(pw.SizedBox(height: 16));
            }

            // Itinerary section
            if (itineraryDocs.isNotEmpty) {
              widgets.add(_buildSectionTitle('Daily Itinerary', font, primaryColor));
              widgets.add(pw.SizedBox(height: 8));
              widgets.addAll(_buildCompactItinerary(itineraryDocs, trip.startDate, font, primaryColor, accentColor, successColor, accommodationDoc));
            }

            // Footer
            widgets.add(pw.SizedBox(height: 16));
            widgets.add(_buildFooter(font, primaryColor));

            print('🔧 Built ${widgets.length} widgets');
            return widgets;
          },
        ),
      );

      print('🔧 Saving PDF...');
      final bytes = await pdf.save();
      print('✅ PDF saved: ${bytes.length} bytes');
      return bytes;

    } catch (e, stackTrace) {
      print('❌ Error in PDF generation: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Builds PDF header with trip name
  pw.Widget _buildCompactHeader(TripModel trip, PdfColor color, pw.Font font) {
    return pw.Container(
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(8)),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('TRAVEL ITINERARY', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.white.shade(0.8))),
          pw.SizedBox(height: 6),
          pw.Text(trip.tripName.toUpperCase(), style: pw.TextStyle(font: font, fontSize: 18, color: PdfColors.white)),
          pw.SizedBox(height: 6),
          pw.Text('${trip.destinationCity}, ${trip.destinationCountry}', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
        ],
      ),
    );
  }

  /// Builds overview section with dates and budget
  pw.Widget _buildCompactOverview(TripModel trip, PdfColor primaryColor, PdfColor accentColor, PdfColor successColor, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildCompactStat('Duration', '${trip.durationInDays} Days', primaryColor, font),
          _buildCompactStat('From', DateFormat('MMM d').format(trip.startDate), accentColor, font),
          _buildCompactStat('To', DateFormat('MMM d, y').format(trip.endDate), accentColor, font),
          if (trip.totalEstimatedBudgetMYR != null)
            _buildCompactStat('Budget', 'RM ${trip.totalEstimatedBudgetMYR!.toStringAsFixed(0)}', successColor, font),
        ],
      ),
    );
  }

  /// Builds single stat item
  pw.Widget _buildCompactStat(String label, String value, PdfColor color, pw.Font font) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10, color: color)),
      ],
    );
  }

  /// Builds section title
  pw.Widget _buildSectionTitle(String title, pw.Font font, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        border: pw.Border(left: pw.BorderSide(color: color, width: 3)),
      ),
      child: pw.Text(title, style: pw.TextStyle(font: font, fontSize: 12, color: color)),
    );
  }

  /// Builds accommodations section
  List<pw.Widget> _buildCompactAccommodations(DocumentSnapshot doc, pw.Font font, PdfColor primaryColor, PdfColor successColor) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return [];

    final widgets = <pw.Widget>[];

    // Get recommended accommodation
    Map<String, dynamic>? recommended;
    if (data['recommendedAccommodation'] != null) {
      recommended = data['recommendedAccommodation'] as Map<String, dynamic>;
    } else if (data['accommodations'] != null && (data['accommodations'] as List).isNotEmpty) {
      recommended = (data['accommodations'] as List).first as Map<String, dynamic>;
    }

    if (recommended != null) {
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 28,
                height: 28,
                decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Center(child: pw.Text('H', style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.white))),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(recommended['name'] ?? 'Accommodation', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.black)),
                    if (recommended['address'] != null)
                      pw.Text(recommended['address'], style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600), maxLines: 1),
                  ],
                ),
              ),
              if (recommended['price_per_night_myr'] != null)
                pw.Text('RM ${recommended['price_per_night_myr']}', style: pw.TextStyle(font: font, fontSize: 9, color: successColor)),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  /// Builds daily itinerary section
  List<pw.Widget> _buildCompactItinerary(
      List<QueryDocumentSnapshot> docs,
      DateTime startDate,
      pw.Font font,
      PdfColor primaryColor,
      PdfColor accentColor,
      PdfColor successColor,
      DocumentSnapshot? accommodationDoc,
      ) {
    print('🔧 Building itinerary...');
    final itemsByDay = _groupItemsByDay(docs);
    final sortedDays = itemsByDay.keys.toList()..sort();
    final widgets = <pw.Widget>[];

    // Get accommodation for "Start from Hotel" card
    Map<String, dynamic>? recommendedAccommodation;
    if (accommodationDoc != null && accommodationDoc.exists) {
      final accData = accommodationDoc.data() as Map<String, dynamic>?;
      if (accData != null) {
        if (accData['recommendedAccommodation'] != null) {
          recommendedAccommodation = accData['recommendedAccommodation'] as Map<String, dynamic>;
        } else if (accData['accommodations'] != null && (accData['accommodations'] as List).isNotEmpty) {
          recommendedAccommodation = (accData['accommodations'] as List).first as Map<String, dynamic>;
        }
      }
    }

    // Build each day
    for (var dayNumber in sortedDays) {
      final date = startDate.add(Duration(days: dayNumber - 1));
      final dayItems = itemsByDay[dayNumber]!;

      // Day header
      widgets.add(
        pw.Container(
          margin: pw.EdgeInsets.only(bottom: 6, top: dayNumber > 1 ? 12 : 0),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(
            children: [
              pw.Container(
                width: 28,
                height: 28,
                decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Center(child: pw.Text('$dayNumber', style: pw.TextStyle(font: font, fontSize: 14, color: primaryColor))),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Day $dayNumber', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
                    pw.Text(DateFormat('EEE, MMM d').format(date), style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      // Add "Start from Hotel" card
      if (recommendedAccommodation != null) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F3E5F5'),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColor.fromHex('#CE93D8'), width: 1.5),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 28,
                  height: 28,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#9C27B0'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Center(
                    child: pw.Text('H', style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Start from ${recommendedAccommodation['name'] ?? 'Hotel'}',
                        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black, fontWeight: pw.FontWeight.bold),
                        maxLines: 1,
                      ),
                      if (recommendedAccommodation['address'] != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          recommendedAccommodation['address'],
                          style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600),
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Add activities for this day
      for (var item in dayItems) {
        final activityColor = _getActivityColor(item);
        final title = item['title'] ?? 'Activity';
        final location = item['location'];
        final timeRange = _formatTimeRange(item);

        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: activityColor.shade(0.2), width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    if (timeRange.isNotEmpty) ...[
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: pw.BoxDecoration(color: activityColor.shade(0.1), borderRadius: pw.BorderRadius.circular(3)),
                        child: pw.Text(timeRange, style: pw.TextStyle(font: font, fontSize: 7, color: activityColor)),
                      ),
                      pw.SizedBox(width: 6),
                    ],
                    pw.Expanded(child: pw.Text(title, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black))),
                  ],
                ),
                if (location != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(location, style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600), maxLines: 1),
                ],
                // Show restaurant options for meals
                if (_isMealCategory(item['category']?.toString().toLowerCase() ?? '')) ...[
                  pw.SizedBox(height: 3),
                  _buildRestaurantOption(item, font),
                ],
              ],
            ),
          ),
        );
      }
    }

    print('🔧 Itinerary done: ${widgets.length} widgets');
    return widgets;
  }

  /// Builds restaurant option display
  pw.Widget _buildRestaurantOption(Map<String, dynamic> item, pw.Font font) {
    final restaurants = item['restaurantOptions'] as List? ?? [];
    if (restaurants.isEmpty) return pw.SizedBox.shrink();

    final first = restaurants.first as Map<String, dynamic>;
    final name = first['name']?.toString() ?? '';
    if (name.trim().isEmpty) return pw.SizedBox.shrink();

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: PdfColor.fromHex('#D84315'), width: 1.5),
      ),
      child: pw.Text(
        'Option: $name${restaurants.length > 1 ? " (+${restaurants.length - 1} more)" : ""}',
        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.black, fontWeight: pw.FontWeight.bold),
        maxLines: 1,
      ),
    );
  }

  /// Builds PDF footer
  pw.Widget _buildFooter(pw.Font font, PdfColor primaryColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Generated ${DateFormat('MMM d, y').format(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 6, color: PdfColors.grey600)),
        pw.Text('Wandry', style: pw.TextStyle(font: font, fontSize: 8, color: primaryColor)),
      ],
    );
  }

  /// Builds text content for sharing
  String _buildTextContent(TripModel trip, List<QueryDocumentSnapshot> itineraryDocs, DocumentSnapshot? accommodationDoc) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('=' * 70);
    buffer.writeln(trip.tripName.toUpperCase().padLeft(35 + trip.tripName.length ~/ 2));
    buffer.writeln('=' * 70);
    buffer.writeln();

    // Trip details
    buffer.writeln('TRIP DETAILS');
    buffer.writeln('-' * 70);
    buffer.writeln('Destination: ${trip.destinationCity}, ${trip.destinationCountry}');
    buffer.writeln('Dates: ${DateFormat('MMM d, y').format(trip.startDate)} - ${DateFormat('MMM d, y').format(trip.endDate)}');
    buffer.writeln('Duration: ${trip.durationInDays} days');
    if (trip.totalEstimatedBudgetMYR != null) {
      buffer.writeln('Budget: RM ${trip.totalEstimatedBudgetMYR!.toStringAsFixed(2)}');
    }
    buffer.writeln();

    // Accommodation
    if (accommodationDoc != null && accommodationDoc.exists) {
      final data = accommodationDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        Map<String, dynamic>? recommended;
        if (data['recommendedAccommodation'] != null) {
          recommended = data['recommendedAccommodation'] as Map<String, dynamic>;
        } else if (data['accommodations'] != null && (data['accommodations'] as List).isNotEmpty) {
          recommended = (data['accommodations'] as List).first as Map<String, dynamic>;
        }

        if (recommended != null) {
          buffer.writeln('ACCOMMODATIONS');
          buffer.writeln('-' * 70);
          buffer.writeln('> ${recommended['name'] ?? 'Accommodation'}');
          if (recommended['address'] != null) buffer.writeln('  Address: ${recommended['address']}');
          if (recommended['price_per_night_myr'] != null) buffer.writeln('  Price: RM ${recommended['price_per_night_myr']}/night');
          buffer.writeln();
        }
      }
    }

    // Daily itinerary
    if (itineraryDocs.isNotEmpty) {
      buffer.writeln('DAILY ITINERARY');
      buffer.writeln('=' * 70);
      final itemsByDay = _groupItemsByDay(itineraryDocs);
      final sortedDays = itemsByDay.keys.toList()..sort();

      for (var dayNumber in sortedDays) {
        final date = trip.startDate.add(Duration(days: dayNumber - 1));
        buffer.writeln('\nDAY $dayNumber - ${DateFormat('EEEE, MMM d, y').format(date).toUpperCase()}');
        buffer.writeln('-' * 70);

        for (var item in itemsByDay[dayNumber]!) {
          final timeStr = _formatTimeRange(item);
          if (timeStr.isNotEmpty) buffer.write('[$timeStr] ');
          buffer.writeln(item['title'] ?? 'Activity');
          if (item['location'] != null) buffer.writeln('  Location: ${item['location']}');
          if (item['description'] != null && item['description'].toString().isNotEmpty) buffer.writeln('  Notes: ${item['description']}');

          // Restaurant options
          final restaurants = item['restaurantOptions'] as List? ?? [];
          final validRestaurants = restaurants.where((r) {
            final name = ((r as Map<String, dynamic>)['name']?.toString() ?? '').trim();
            return name.isNotEmpty;
          }).toList();

          if (validRestaurants.isNotEmpty) {
            buffer.writeln('  Restaurant Options:');
            for (var i = 0; i < validRestaurants.length && i < 3; i++) {
              final r = validRestaurants[i] as Map<String, dynamic>;
              final name = r['name'] ?? 'Restaurant';
              final cuisine = r['cuisine'] ?? 'Local';
              buffer.writeln('    ${i + 1}. $name - $cuisine');
              if (r['cost_display'] != null) buffer.writeln('       Cost: ${r['cost_display']}');
            }
            if (validRestaurants.length > 3) buffer.writeln('    ...and ${validRestaurants.length - 3} more options');
          }

          if (item['estimatedCost'] != null && item['estimatedCost'] > 0) buffer.writeln('  Cost: RM ${item['estimatedCost']}');
          buffer.writeln();
        }
      }
    }

    // Footer
    buffer.writeln('=' * 70);
    buffer.writeln('Generated on ${DateFormat('MMM d, y').format(DateTime.now())}');
    buffer.writeln('Created with Wandry Trip Planner');
    return buffer.toString();
  }

  /// Groups itinerary items by day number
  Map<int, List<Map<String, dynamic>>> _groupItemsByDay(List<QueryDocumentSnapshot> docs) {
    final itemsByDay = <int, List<Map<String, dynamic>>>{};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dayNumber = data['dayNumber'] as int? ?? 1;
      itemsByDay.putIfAbsent(dayNumber, () => []);
      itemsByDay[dayNumber]!.add(data);
    }
    return itemsByDay;
  }

  /// Returns color based on activity category
  PdfColor _getActivityColor(Map<String, dynamic> item) {
    final category = item['category']?.toString().toLowerCase() ?? '';
    if (_isMealCategory(category)) return PdfColor.fromHex('#FF6F00');
    if (_isAttractionCategory(category)) return PdfColor.fromHex('#1E88E5');
    return PdfColor.fromHex('#43A047');
  }

  /// Formats time range from item data
  String _formatTimeRange(Map<String, dynamic> item) {
    try {
      DateTime? startTime;
      DateTime? endTime;
      if (item['startTime'] != null) {
        startTime = item['startTime'] is Timestamp ? (item['startTime'] as Timestamp).toDate() : DateTime.parse(item['startTime'].toString());
      }
      if (item['endTime'] != null) {
        endTime = item['endTime'] is Timestamp ? (item['endTime'] as Timestamp).toDate() : DateTime.parse(item['endTime'].toString());
      }
      if (startTime != null) {
        String result = DateFormat('HH:mm').format(startTime);
        if (endTime != null) result += '-${DateFormat('HH:mm').format(endTime)}';
        return result;
      }
    } catch (e) {}
    return '';
  }

  // Category checkers
  bool _isMealCategory(String c) => ['breakfast', 'lunch', 'dinner', 'meal', 'food', 'dining'].contains(c);
  bool _isAttractionCategory(String c) => ['attraction', 'museum', 'park', 'temple', 'landmark', 'monument', 'cultural', 'nature', 'beach'].contains(c);
  bool _isEntertainmentCategory(String c) => ['entertainment', 'shopping', 'nightlife', 'activity', 'sports', 'recreation'].contains(c);

  /// Shows success snackbar
  void _showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows error snackbar
  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}