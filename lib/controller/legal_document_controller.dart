import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/legal_document_model.dart';

/// LegalDocumentController - Manages Terms & Conditions and Privacy Policy
class LegalDocumentController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LegalDocument? _termsAndConditions;
  LegalDocument? _privacyPolicy;
  bool _isLoading = false;
  String? _error;

  LegalDocument? get termsAndConditions => _termsAndConditions;
  LegalDocument? get privacyPolicy => _privacyPolicy;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Collection reference for legal documents
  CollectionReference get _legalDocsRef => _firestore.collection('legalDocuments');

  /// Fetch Terms and Conditions
  Future<LegalDocument?> fetchTermsAndConditions() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final doc = await _legalDocsRef.doc('termsAndConditions').get();

      if (doc.exists) {
        _termsAndConditions = LegalDocument.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      } else {
        // Create default document if not exists
        _termsAndConditions = _getDefaultTermsAndConditions();
        await saveTermsAndConditions(_termsAndConditions!);
      }

      return _termsAndConditions;
    } catch (e) {
      _error = 'Failed to fetch Terms and Conditions: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch Privacy Policy
  Future<LegalDocument?> fetchPrivacyPolicy() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final doc = await _legalDocsRef.doc('privacyPolicy').get();

      if (doc.exists) {
        _privacyPolicy = LegalDocument.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      } else {
        // Create default document if not exists
        _privacyPolicy = _getDefaultPrivacyPolicy();
        await savePrivacyPolicy(_privacyPolicy!);
      }

      return _privacyPolicy;
    } catch (e) {
      _error = 'Failed to fetch Privacy Policy: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save Terms and Conditions
  Future<bool> saveTermsAndConditions(LegalDocument document) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updatedDoc = document.copyWith(
        updatedAt: DateTime.now(),
      );

      await _legalDocsRef.doc('termsAndConditions').set(updatedDoc.toFirestore());
      _termsAndConditions = updatedDoc;

      return true;
    } catch (e) {
      _error = 'Failed to save Terms and Conditions: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save Privacy Policy
  Future<bool> savePrivacyPolicy(LegalDocument document) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updatedDoc = document.copyWith(
        updatedAt: DateTime.now(),
      );

      await _legalDocsRef.doc('privacyPolicy').set(updatedDoc.toFirestore());
      _privacyPolicy = updatedDoc;

      return true;
    } catch (e) {
      _error = 'Failed to save Privacy Policy: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get document version history
  Future<List<DocumentVersion>> getVersionHistory(String documentType) async {
    try {
      final snapshot = await _legalDocsRef
          .doc(documentType)
          .collection('versions')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        return DocumentVersion.fromFirestore(
          doc.data(),
          doc.id,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching version history: $e');
      return [];
    }
  }

  /// Save a version before updating
  Future<void> _saveVersion(String documentType, LegalDocument document) async {
    try {
      final version = DocumentVersion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: document.sections,
        version: document.version,
        createdAt: DateTime.now(),
        createdBy: document.lastEditedBy ?? 'Unknown',
      );

      await _legalDocsRef
          .doc(documentType)
          .collection('versions')
          .doc(version.id)
          .set(version.toFirestore());
    } catch (e) {
      debugPrint('Error saving version: $e');
    }
  }

  /// Default Terms and Conditions
  LegalDocument _getDefaultTermsAndConditions() {
    return LegalDocument(
      id: 'termsAndConditions',
      title: 'Terms & Conditions',
      version: '1.0.0',
      effectiveDate: DateTime.now(),
      updatedAt: DateTime.now(),
      sections: [
        DocumentSection(
          title: 'Acceptance of Terms',
          content: 'By accessing and using Wandry (the "Service"), you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to these Terms & Conditions, please do not use our Service.\n\nYour continued use of the Service following the posting of any changes to these terms constitutes acceptance of those changes.',
          order: 1,
        ),
        DocumentSection(
          title: 'User Accounts',
          content: '2.1. Account Creation: You must create an account to access certain features of the Service. You agree to provide accurate, current, and complete information during registration.\n\n2.2. Account Security: You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.\n\n2.3. Account Termination: We reserve the right to suspend or terminate your account if you violate these terms or engage in fraudulent or illegal activities.',
          order: 2,
        ),
        DocumentSection(
          title: 'Service Description',
          content: 'Wandry provides a trip planning platform that allows users to:\n• Plan and organize trips\n• Book travel services\n• Share itineraries with other users\n• Access travel recommendations and guides\n• Connect with travel service providers\n\nWe reserve the right to modify, suspend, or discontinue any part of the Service at any time without prior notice.',
          order: 3,
        ),
        DocumentSection(
          title: 'User Responsibilities',
          content: '4.1. You agree to use the Service only for lawful purposes and in accordance with these Terms.\n\n4.2. You will not:\n• Use the Service to transmit any harmful, offensive, or illegal content\n• Attempt to gain unauthorized access to the Service or other user accounts\n• Interfere with or disrupt the Service or servers\n• Impersonate any person or entity\n• Collect or harvest personal information from other users\n• Use automated systems to access the Service without permission',
          order: 4,
        ),
        DocumentSection(
          title: 'Bookings and Payments',
          content: '5.1. Third-Party Services: Wandry may facilitate bookings with third-party service providers (hotels, airlines, tour operators). These bookings are subject to the terms and conditions of those providers.\n\n5.2. Pricing: All prices displayed are subject to change without notice. The final price will be confirmed at the time of booking.\n\n5.3. Payment: Payment for services must be made through the payment methods provided in the Service. You agree to provide valid payment information.\n\n5.4. Cancellations and Refunds: Cancellation and refund policies are determined by the respective service providers and will be communicated at the time of booking.',
          order: 5,
        ),
        DocumentSection(
          title: 'User Content',
          content: '6.1. Ownership: You retain ownership of any content you post, upload, or share through the Service ("User Content").\n\n6.2. License: By posting User Content, you grant Wandry a worldwide, non-exclusive, royalty-free license to use, reproduce, modify, and display such content for the purpose of operating and improving the Service.\n\n6.3. Responsibility: You are solely responsible for your User Content and any consequences of posting or publishing it. You represent that you own or have the necessary rights to all User Content you post.',
          order: 6,
        ),
        DocumentSection(
          title: 'Intellectual Property',
          content: 'The Service and its original content, features, and functionality are owned by Wandry and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.\n\nYou may not copy, modify, distribute, sell, or lease any part of our Service without our express written permission.',
          order: 7,
        ),
        DocumentSection(
          title: 'Disclaimers',
          content: '8.1. Service "As Is": The Service is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind, either express or implied.\n\n8.2. Travel Information: While we strive to provide accurate information, we do not guarantee the accuracy, completeness, or reliability of any travel information, recommendations, or content on the Service.\n\n8.3. Third-Party Services: We are not responsible for the services provided by third-party vendors, including hotels, airlines, and tour operators. Any issues with such services should be addressed directly with the provider.',
          order: 8,
        ),
        DocumentSection(
          title: 'Limitation of Liability',
          content: 'To the maximum extent permitted by law, Wandry shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including loss of profits, data, or other intangible losses resulting from:\n• Your use or inability to use the Service\n• Any unauthorized access to your account or personal information\n• Any interruption or cessation of the Service\n• Any errors or omissions in content\n• Any conduct or content of third parties on the Service',
          order: 9,
        ),
        DocumentSection(
          title: 'Contact Information',
          content: 'If you have any questions about these Terms & Conditions, please contact us at:\n\nEmail: support@wandry.com\nWebsite: www.wandry.com',
          order: 10,
        ),
      ],
    );
  }

  /// Default Privacy Policy
  LegalDocument _getDefaultPrivacyPolicy() {
    return LegalDocument(
      id: 'privacyPolicy',
      title: 'Privacy Policy',
      version: '1.0.0',
      effectiveDate: DateTime.now(),
      updatedAt: DateTime.now(),
      sections: [
        DocumentSection(
          title: 'Information We Collect',
          content: '1.1. Personal Information\nWhen you create an account with Wandry, we collect:\n• Name (first and last name)\n• Email address\n• Contact number\n• Password (encrypted)\n• Profile information you choose to provide\n\n1.2. Trip Information\n• Trip itineraries and plans\n• Booking information\n• Travel preferences\n• Destination searches and interests\n• Reviews and ratings you provide\n\n1.3. Usage Information\n• Device information (device type, operating system, unique device identifiers)\n• Log data (IP address, access times, pages viewed)\n• Location data (with your permission)\n• Cookies and similar tracking technologies\n\n1.4. Payment Information\n• Payment card details (processed securely through third-party payment processors)\n• Billing address\n• Transaction history',
          order: 1,
        ),
        DocumentSection(
          title: 'How We Use Your Information',
          content: 'We use the information we collect to:\n\n2.1. Provide and Improve Services\n• Create and manage your account\n• Process your bookings and transactions\n• Provide customer support\n• Send you trip confirmations and updates\n• Improve and personalize your experience\n• Develop new features and services\n\n2.2. Communication\n• Send you service-related notifications\n• Respond to your inquiries and requests\n• Send promotional materials (with your consent)\n• Share travel tips and recommendations\n\n2.3. Safety and Security\n• Verify your identity\n• Detect and prevent fraud\n• Protect against unauthorized access\n• Comply with legal obligations',
          order: 2,
        ),
        DocumentSection(
          title: 'How We Share Your Information',
          content: '3.1. Service Providers\nWe share your information with third-party service providers who help us operate our business:\n• Payment processors\n• Cloud storage providers\n• Analytics services\n• Customer support tools\n• Marketing platforms\n\n3.2. Travel Partners\nWhen you make bookings, we share relevant information with:\n• Hotels and accommodations\n• Airlines and transportation services\n• Tour operators\n• Activity providers\n\n3.3. Legal Requirements\nWe may disclose your information:\n• To comply with legal obligations\n• To respond to lawful requests from authorities\n• To protect our rights and property\n• To prevent fraud or illegal activities',
          order: 3,
        ),
        DocumentSection(
          title: 'Data Security',
          content: 'We implement appropriate technical and organizational measures to protect your personal information:\n\n• Encryption of data in transit and at rest\n• Secure authentication mechanisms\n• Regular security assessments\n• Access controls and monitoring\n• Employee training on data protection\n\nHowever, no method of transmission over the internet or electronic storage is 100% secure. While we strive to protect your data, we cannot guarantee absolute security.',
          order: 4,
        ),
        DocumentSection(
          title: 'Your Rights and Choices',
          content: '5.1. Access and Correction\n• You can access and update your account information at any time through your profile settings\n\n5.2. Data Portability\n• You can request a copy of your personal information in a commonly used format\n\n5.3. Deletion\n• You can request deletion of your account and personal information\n• Some information may be retained as required by law\n\n5.4. Marketing Communications\n• You can opt out of promotional emails by clicking the unsubscribe link\n• You will still receive service-related communications',
          order: 5,
        ),
        DocumentSection(
          title: 'Children\'s Privacy',
          content: 'Wandry is not intended for users under the age of 18. We do not knowingly collect personal information from children under 18.\n\nIf you are a parent or guardian and believe your child has provided us with personal information, please contact us, and we will delete such information.',
          order: 6,
        ),
        DocumentSection(
          title: 'Changes to This Privacy Policy',
          content: 'We may update this Privacy Policy from time to time. We will notify you of any material changes by:\n• Posting the updated policy on this page\n• Updating the "Last Updated" date\n• Sending you an email notification (for significant changes)\n\nYour continued use of the Service after such changes constitutes your acceptance of the updated Privacy Policy.',
          order: 7,
        ),
        DocumentSection(
          title: 'Contact Us',
          content: 'If you have any questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us:\n\nEmail: privacy@wandry.com\nSupport Email: support@wandry.com\nWebsite: www.wandry.com\n\nData Protection Officer:\nEmail: dpo@wandry.com\n\nWe will respond to your inquiries within a reasonable timeframe.',
          order: 8,
        ),
      ],
    );
  }
}