import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Legal'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Privacy Policy'),
              Tab(text: 'Terms of Service'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PrivacyPolicyTab(),
            _TermsOfServiceTab(),
          ],
        ),
      ),
    );
  }
}

// ── Privacy Policy ──────────────────────────────────────────────────────────

class _PrivacyPolicyTab extends StatelessWidget {
  const _PrivacyPolicyTab();

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Privacy Policy', style: ts.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Last updated: March 2026',
            style: ts.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            title: '1. Information We Collect',
            body:
                'We collect the following information when you use WyseBrix:\n\n'
                '• Account information: your name and email address when you register.\n'
                '• Profile information: professional details you add to your builder or project manager profile.\n'
                '• Project data: project titles, budgets, costs, phases, and updates you create.\n'
                '• Location data: GPS coordinates attached to site photos (only when you explicitly capture a photo within the app).\n'
                '• Photos and documents: images and files you upload to project updates or cost receipts.\n'
                '• Device information: device type and operating system version, collected automatically for crash reporting.',
          ),
          _Section(
            title: '2. How We Use Your Information',
            body:
                'We use the information we collect to:\n\n'
                '• Provide and operate the WyseBrix service.\n'
                '• Send push notifications about your projects, contracts, and quotes (you can control these in Notification Preferences).\n'
                '• Process payments through our payment partner, Paystack.\n'
                '• Diagnose and fix technical issues using crash reports.\n'
                '• Improve the app based on anonymised usage analytics.',
          ),
          _Section(
            title: '3. Data Storage',
            body:
                'Your data is stored securely using Google Firebase services (Firestore, Firebase Storage) '
                'on servers located in the United States. Firebase is operated by Google LLC and adheres to '
                'industry-standard security practices.',
          ),
          _Section(
            title: '4. Crash Reporting',
            body:
                'In production builds, we use Firebase Crashlytics to automatically collect crash reports. '
                'These reports include device information and the state of the app at the time of the crash. '
                'No personally identifiable information beyond your Firebase user ID is included in crash reports.',
          ),
          _Section(
            title: '5. Push Notifications',
            body:
                'We use Firebase Cloud Messaging (FCM) to send push notifications. Your device token is '
                'stored in your user record and is used solely to deliver notifications. You can disable '
                'notifications at any time from the Notification Preferences screen in the app or from '
                'your device settings.',
          ),
          _Section(
            title: '6. Payment Processing',
            body:
                'Payments within WyseBrix are processed by Paystack (paystack.com). When you initiate '
                'a payment, you are redirected to a secure Paystack checkout. WyseBrix does not store '
                'your card or mobile money details. Please review Paystack\'s privacy policy for details '
                'on how they handle payment information.',
          ),
          _Section(
            title: '7. Data Sharing',
            body:
                'We do not sell your personal information to third parties. We share data only with:\n\n'
                '• Firebase / Google — to store and deliver your data.\n'
                '• Paystack — to process payments you initiate.\n'
                '• Other WyseBrix users — only the information you explicitly publish to your public profile '
                '(e.g., builder or PM profile details).',
          ),
          _Section(
            title: '8. Your Rights',
            body:
                'You have the right to:\n\n'
                '• Access the personal information we hold about you.\n'
                '• Request correction of inaccurate information.\n'
                '• Request deletion of your account and associated data. You can do this directly from '
                'Account → Delete Account in the app.\n\n'
                'For other data requests, contact us at: support@wysebrix.com',
          ),
          _Section(
            title: '9. Children\'s Privacy',
            body:
                'WyseBrix is not intended for use by individuals under the age of 18. We do not '
                'knowingly collect personal information from children.',
          ),
          _Section(
            title: '10. Changes to This Policy',
            body:
                'We may update this Privacy Policy from time to time. We will notify you of significant '
                'changes through the app or by email. Continued use of the app after changes constitutes '
                'acceptance of the updated policy.',
          ),
          _Section(
            title: '11. Contact',
            body:
                'If you have questions about this Privacy Policy, contact us at:\n\n'
                'Email: support@wysebrix.com',
          ),
        ],
      ),
    );
  }
}

// ── Terms of Service ────────────────────────────────────────────────────────

class _TermsOfServiceTab extends StatelessWidget {
  const _TermsOfServiceTab();

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Terms of Service', style: ts.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Last updated: March 2026',
            style: ts.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            title: '1. Acceptance of Terms',
            body:
                'By downloading, installing, or using WyseBrix ("the App"), you agree to be bound by '
                'these Terms of Service. If you do not agree, please do not use the App.',
          ),
          _Section(
            title: '2. Description of Service',
            body:
                'WyseBrix is a construction cost estimation and project management platform designed '
                'for the Ghanaian construction industry. The App allows users to estimate project costs, '
                'manage construction projects, connect with builders and project managers, and process '
                'payments related to construction work.',
          ),
          _Section(
            title: '3. User Accounts',
            body:
                'You must provide accurate information when creating an account. You are responsible '
                'for maintaining the confidentiality of your account credentials and for all activities '
                'that occur under your account. Notify us immediately at support@wysebrix.com if you '
                'suspect unauthorised access to your account.',
          ),
          _Section(
            title: '4. Acceptable Use',
            body:
                'You agree not to:\n\n'
                '• Use the App for any unlawful purpose.\n'
                '• Upload false, misleading, or fraudulent project or profile information.\n'
                '• Attempt to reverse engineer, hack, or disrupt the App or its services.\n'
                '• Use the App to harass, defraud, or harm other users.\n'
                '• Impersonate another person or organisation.',
          ),
          _Section(
            title: '5. Payment Terms',
            body:
                'Payments between users (e.g., contractor payments) are processed by Paystack. '
                'WyseBrix facilitates the payment flow but is not a party to the financial transaction '
                'between project owners and contractors. You agree to Paystack\'s terms of service when '
                'initiating a payment. WyseBrix is not liable for payment failures or disputes between '
                'users.',
          ),
          _Section(
            title: '6. User Content',
            body:
                'You retain ownership of any content you upload (photos, documents, project data). '
                'By uploading content, you grant WyseBrix a non-exclusive, royalty-free licence to '
                'store and display that content solely for the purpose of providing the service to you.',
          ),
          _Section(
            title: '7. Disclaimer of Warranties',
            body:
                'The App is provided "as is" without warranties of any kind, express or implied. '
                'WyseBrix does not warrant that the App will be uninterrupted, error-free, or that '
                'cost estimates produced by the App will be accurate for any specific project. '
                'Estimates are for guidance only and should be validated by a qualified professional.',
          ),
          _Section(
            title: '8. Limitation of Liability',
            body:
                'To the maximum extent permitted by law, WyseBrix and its affiliates shall not be '
                'liable for any indirect, incidental, special, or consequential damages arising from '
                'your use of the App, including but not limited to loss of profits, data, or '
                'construction project losses.',
          ),
          _Section(
            title: '9. Termination',
            body:
                'We reserve the right to suspend or terminate your account if you violate these Terms. '
                'You may delete your account at any time from Account → Delete Account in the App.',
          ),
          _Section(
            title: '10. Governing Law',
            body:
                'These Terms are governed by the laws of the Republic of Ghana. Any disputes shall be '
                'resolved in the courts of Ghana.',
          ),
          _Section(
            title: '11. Changes to Terms',
            body:
                'We may update these Terms from time to time. Continued use of the App after changes '
                'constitutes acceptance of the updated Terms. We will notify you of material changes '
                'via the App or email.',
          ),
          _Section(
            title: '12. Contact',
            body:
                'Questions about these Terms? Contact us at:\n\n'
                'Email: support@wysebrix.com',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Shared helper ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ts.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: ts.bodyMedium),
        ],
      ),
    );
  }
}
