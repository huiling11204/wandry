import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Terms & Conditions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last Updated: November 14, 2025',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 24),

              _buildIntroduction(theme),
              SizedBox(height: 24),

              _buildSection(
                theme,
                '1. Acceptance of Terms',
                'By accessing and using Wandry (the "Service"), you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to these Terms & Conditions, please do not use our Service.\n\nYour continued use of the Service following the posting of any changes to these terms constitutes acceptance of those changes.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '2. User Accounts',
                '2.1. Account Creation: You must create an account to access certain features of the Service. You agree to provide accurate, current, and complete information during registration.\n\n2.2. Account Security: You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.\n\n2.3. Account Termination: We reserve the right to suspend or terminate your account if you violate these terms or engage in fraudulent or illegal activities.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '3. Service Description',
                'Wandry provides a trip planning platform that allows users to:\n• Plan and organize trips\n• Book travel services\n• Share itineraries with other users\n• Access travel recommendations and guides\n• Connect with travel service providers\n\nWe reserve the right to modify, suspend, or discontinue any part of the Service at any time without prior notice.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '4. User Responsibilities',
                '4.1. You agree to use the Service only for lawful purposes and in accordance with these Terms.\n\n4.2. You will not:\n• Use the Service to transmit any harmful, offensive, or illegal content\n• Attempt to gain unauthorized access to the Service or other user accounts\n• Interfere with or disrupt the Service or servers\n• Impersonate any person or entity\n• Collect or harvest personal information from other users\n• Use automated systems to access the Service without permission',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '5. Bookings and Payments',
                '5.1. Third-Party Services: Wandry may facilitate bookings with third-party service providers (hotels, airlines, tour operators). These bookings are subject to the terms and conditions of those providers.\n\n5.2. Pricing: All prices displayed are subject to change without notice. The final price will be confirmed at the time of booking.\n\n5.3. Payment: Payment for services must be made through the payment methods provided in the Service. You agree to provide valid payment information.\n\n5.4. Cancellations and Refunds: Cancellation and refund policies are determined by the respective service providers and will be communicated at the time of booking.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '6. User Content',
                '6.1. Ownership: You retain ownership of any content you post, upload, or share through the Service ("User Content").\n\n6.2. License: By posting User Content, you grant Wandry a worldwide, non-exclusive, royalty-free license to use, reproduce, modify, and display such content for the purpose of operating and improving the Service.\n\n6.3. Responsibility: You are solely responsible for your User Content and any consequences of posting or publishing it. You represent that you own or have the necessary rights to all User Content you post.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '7. Intellectual Property',
                'The Service and its original content, features, and functionality are owned by Wandry and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.\n\nYou may not copy, modify, distribute, sell, or lease any part of our Service without our express written permission.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '8. Disclaimers',
                '8.1. Service "As Is": The Service is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind, either express or implied.\n\n8.2. Travel Information: While we strive to provide accurate information, we do not guarantee the accuracy, completeness, or reliability of any travel information, recommendations, or content on the Service.\n\n8.3. Third-Party Services: We are not responsible for the services provided by third-party vendors, including hotels, airlines, and tour operators. Any issues with such services should be addressed directly with the provider.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '9. Limitation of Liability',
                'To the maximum extent permitted by law, Wandry shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including loss of profits, data, or other intangible losses resulting from:\n• Your use or inability to use the Service\n• Any unauthorized access to your account or personal information\n• Any interruption or cessation of the Service\n• Any errors or omissions in content\n• Any conduct or content of third parties on the Service',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '10. Indemnification',
                'You agree to indemnify, defend, and hold harmless Wandry and its officers, directors, employees, and agents from any claims, liabilities, damages, losses, and expenses, including reasonable attorney fees, arising out of or in any way connected with your access to or use of the Service, your violation of these Terms, or your violation of any rights of another party.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '11. Travel Advisories and Safety',
                '11.1. You are responsible for reviewing travel advisories, visa requirements, health recommendations, and safety information for your destinations.\n\n11.2. Wandry is not responsible for any travel delays, cancellations, natural disasters, political unrest, health emergencies, or other events beyond our control that may affect your trip.\n\n11.3. We recommend purchasing appropriate travel insurance to protect against unforeseen circumstances.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '12. Modifications to Terms',
                'We reserve the right to modify these Terms at any time. We will notify users of any material changes by posting the new Terms on this page and updating the "Last Updated" date.\n\nYour continued use of the Service after such modifications constitutes your acceptance of the updated Terms.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '13. Governing Law',
                'These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which Wandry operates, without regard to its conflict of law provisions.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '14. Dispute Resolution',
                '14.1. Informal Resolution: In the event of any dispute, you agree to first contact us to attempt to resolve the dispute informally.\n\n14.2. Arbitration: If the dispute cannot be resolved informally, you agree that the dispute will be resolved through binding arbitration in accordance with the rules of the applicable arbitration authority.\n\n14.3. Class Action Waiver: You agree to resolve disputes with us on an individual basis and waive your right to participate in class action lawsuits.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '15. Severability',
                'If any provision of these Terms is found to be unenforceable or invalid, that provision will be limited or eliminated to the minimum extent necessary so that these Terms will otherwise remain in full force and effect.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '16. Contact Information',
                'If you have any questions about these Terms & Conditions, please contact us at:\n\nEmail: support@wandry.com\nWebsite: www.wandry.com',
              ),
              SizedBox(height: 40),

              // Accept Button (optional)
              Center(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: theme.outlinedButtonTheme.style,
                  child: Text('I Understand'),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Wandry!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Please read these Terms and Conditions ("Terms") carefully before using the Wandry mobile application and services. These Terms govern your access to and use of our trip planning platform.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[800],
            height: 1.6,
          ),
        ),
      ],
    );
  }
}