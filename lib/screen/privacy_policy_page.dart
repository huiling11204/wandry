import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
          'Privacy Policy',
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
                '1. Information We Collect',
                '1.1. Personal Information\nWhen you create an account with Wandry, we collect:\n• Name (first and last name)\n• Email address\n• Contact number\n• Password (encrypted)\n• Profile information you choose to provide\n\n1.2. Trip Information\n• Trip itineraries and plans\n• Booking information\n• Travel preferences\n• Destination searches and interests\n• Reviews and ratings you provide\n\n1.3. Usage Information\n• Device information (device type, operating system, unique device identifiers)\n• Log data (IP address, access times, pages viewed)\n• Location data (with your permission)\n• Cookies and similar tracking technologies\n\n1.4. Payment Information\n• Payment card details (processed securely through third-party payment processors)\n• Billing address\n• Transaction history',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '2. How We Use Your Information',
                'We use the information we collect to:\n\n2.1. Provide and Improve Services\n• Create and manage your account\n• Process your bookings and transactions\n• Provide customer support\n• Send you trip confirmations and updates\n• Improve and personalize your experience\n• Develop new features and services\n\n2.2. Communication\n• Send you service-related notifications\n• Respond to your inquiries and requests\n• Send promotional materials (with your consent)\n• Share travel tips and recommendations\n\n2.3. Safety and Security\n• Verify your identity\n• Detect and prevent fraud\n• Protect against unauthorized access\n• Comply with legal obligations\n\n2.4. Analytics and Research\n• Analyze usage patterns and trends\n• Conduct research to improve our services\n• Generate aggregated, anonymized statistics',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '3. How We Share Your Information',
                '3.1. Service Providers\nWe share your information with third-party service providers who help us operate our business:\n• Payment processors\n• Cloud storage providers\n• Analytics services\n• Customer support tools\n• Marketing platforms\n\n3.2. Travel Partners\nWhen you make bookings, we share relevant information with:\n• Hotels and accommodations\n• Airlines and transportation services\n• Tour operators\n• Activity providers\n\n3.3. Other Users\nDepending on your privacy settings:\n• Profile information you choose to make public\n• Trip itineraries you share\n• Reviews and ratings\n\n3.4. Legal Requirements\nWe may disclose your information:\n• To comply with legal obligations\n• To respond to lawful requests from authorities\n• To protect our rights and property\n• To prevent fraud or illegal activities\n• In connection with a business transfer or merger\n\n3.5. With Your Consent\nWe may share your information for other purposes with your explicit consent.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '4. Data Security',
                'We implement appropriate technical and organizational measures to protect your personal information:\n\n• Encryption of data in transit and at rest\n• Secure authentication mechanisms\n• Regular security assessments\n• Access controls and monitoring\n• Employee training on data protection\n\nHowever, no method of transmission over the internet or electronic storage is 100% secure. While we strive to protect your data, we cannot guarantee absolute security.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '5. Data Retention',
                'We retain your personal information for as long as necessary to:\n• Provide our services to you\n• Comply with legal obligations\n• Resolve disputes\n• Enforce our agreements\n\nWhen you delete your account, we will delete or anonymize your personal information, except where we are required to retain it for legal or legitimate business purposes.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '6. Your Rights and Choices',
                '6.1. Access and Correction\n• You can access and update your account information at any time through your profile settings\n\n6.2. Data Portability\n• You can request a copy of your personal information in a commonly used format\n\n6.3. Deletion\n• You can request deletion of your account and personal information\n• Some information may be retained as required by law\n\n6.4. Marketing Communications\n• You can opt out of promotional emails by clicking the unsubscribe link\n• You will still receive service-related communications\n\n6.5. Location Data\n• You can control location permissions through your device settings\n\n6.6. Cookies\n• You can control cookie preferences through your browser settings',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '7. Children\'s Privacy',
                'Wandry is not intended for users under the age of 18. We do not knowingly collect personal information from children under 18.\n\nIf you are a parent or guardian and believe your child has provided us with personal information, please contact us, and we will delete such information.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '8. International Data Transfers',
                'Your information may be transferred to and processed in countries other than your country of residence. These countries may have different data protection laws.\n\nWhen we transfer your information internationally, we ensure appropriate safeguards are in place to protect your data in accordance with this Privacy Policy.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '9. Third-Party Links and Services',
                'Our Service may contain links to third-party websites, services, or applications. We are not responsible for the privacy practices of these third parties.\n\nWe encourage you to review the privacy policies of any third-party services you access through our platform.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '10. Cookies and Tracking Technologies',
                'We use cookies and similar technologies to:\n• Remember your preferences\n• Understand how you use our Service\n• Improve user experience\n• Deliver targeted advertising\n\nTypes of cookies we use:\n• Essential cookies (required for the Service to function)\n• Functional cookies (enhance functionality)\n• Analytics cookies (help us understand usage)\n• Advertising cookies (deliver relevant ads)\n\nYou can control cookies through your browser settings, but disabling cookies may affect Service functionality.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '11. Changes to This Privacy Policy',
                'We may update this Privacy Policy from time to time. We will notify you of any material changes by:\n• Posting the updated policy on this page\n• Updating the "Last Updated" date\n• Sending you an email notification (for significant changes)\n\nYour continued use of the Service after such changes constitutes your acceptance of the updated Privacy Policy.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '12. Your California Privacy Rights',
                'If you are a California resident, you have additional rights under the California Consumer Privacy Act (CCPA):\n\n• Right to know what personal information we collect\n• Right to know whether we sell or share personal information\n• Right to opt out of the sale or sharing of personal information\n• Right to request deletion of personal information\n• Right to non-discrimination for exercising your rights\n\nTo exercise these rights, please contact us using the information below.',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '13. European Privacy Rights (GDPR)',
                'If you are located in the European Economic Area (EEA), you have rights under the General Data Protection Regulation (GDPR):\n\n• Right to access your personal data\n• Right to rectification of inaccurate data\n• Right to erasure ("right to be forgotten")\n• Right to restrict processing\n• Right to data portability\n• Right to object to processing\n• Right to withdraw consent\n• Right to lodge a complaint with a supervisory authority\n\nOur lawful bases for processing your data include:\n• Performance of a contract\n• Legitimate interests\n• Compliance with legal obligations\n• Your consent',
              ),
              SizedBox(height: 20),

              _buildSection(
                theme,
                '14. Contact Us',
                'If you have any questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us:\n\nEmail: privacy@wandry.com\nSupport Email: support@wandry.com\nWebsite: www.wandry.com\n\nData Protection Officer:\nEmail: dpo@wandry.com\n\nWe will respond to your inquiries within a reasonable timeframe.',
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
          'Your Privacy Matters',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'At Wandry, we are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, share, and protect your data when you use our trip planning services.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'By using Wandry, you agree to the collection and use of information in accordance with this Privacy Policy.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[700],
            height: 1.5,
            fontWeight: FontWeight.w500,
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