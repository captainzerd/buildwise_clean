// lib/core/config/router.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/account/builder_profile_page.dart';
import '../../features/account/certifications_page.dart';
import '../../features/account/edit_profile_page.dart';
import '../../features/account/id_verification_page.dart';
import '../../features/account/login_activity_page.dart';
import '../../features/account/portfolio_page.dart';
import '../../features/account/work_experience_page.dart';
import '../../features/project/join_project_page.dart';
import '../../features/admin/complaints_admin_page.dart';
import '../../features/admin/deletion_requests_admin_page.dart';
import '../../features/admin/id_verification_admin_page.dart';
import '../../features/admin/licence_verification_admin_page.dart';
import '../../features/complaints/complaints_page.dart';
import '../../features/vendor/vendors_page.dart';
import '../../features/account/pending_contracts_page.dart';
import '../../features/account/pm_profile_page.dart';
import '../../features/account/vendor_rfq_inbox_page.dart';
import '../../features/admin/admin_page.dart';
import '../../features/admin/audit_admin_page.dart';
import '../../features/admin/boq_rates_admin_page.dart';
import '../../features/admin/catalog_admin_page.dart';
import '../../features/admin/site_visits_admin_page.dart';
import '../../features/admin/users_admin_page.dart';
import '../../features/admin/variation_orders_admin_page.dart';
import '../../features/auth/email_verification_page.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/otp_verification_page.dart';
import '../../features/auth/sign_in_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/estimate/estimate_result_page.dart';
import '../../features/notifications/notification_centre_page.dart';
import '../../features/notifications/notification_prefs_page.dart';
import '../../features/project/builder_profile_detail_page.dart';
import '../../features/project/contract_view_page.dart';
import '../../features/project/create_contract_page.dart';
import '../../features/project/create_project_page.dart';
import '../../features/project/invoice_page.dart';
import '../../features/project/labor_tracking_page.dart';
import '../../features/project/land_ownership_page.dart';
import '../../features/project/project_audit_page.dart';
import '../../features/project/project_details_page.dart';
import '../../features/project/project_quotes_page.dart';
import '../../features/project/project_templates_page.dart';
import '../../features/project/quote_comparison_page.dart';
import '../../features/project/site_visits_page.dart';
import '../../features/project/snag_list_page.dart';
import '../../features/project/variation_orders_page.dart';
import '../../features/saved/saved_estimates_page.dart';
import '../../features/shell/home_shell.dart';
import '../models/builder_contract.dart';
import '../models/builder_profile.dart';
import '../models/project.dart';
import '../models/rfq_request.dart';
import '../services/notification_service.dart';
import '../../features/project/edit_project_page.dart';
import '../../features/legal/legal_page.dart';
import '../../features/account/upgrade_page.dart';
import '../models/app_user.dart';

final appRouter = GoRouter(
  navigatorKey: NotificationService.navigatorKey,
  observers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
  initialLocation: '/',
  redirect: (context, state) async {
    if (state.matchedLocation == '/') {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('onboarding_done') ?? false)) {
        return '/onboarding';
      }
    }
    return null;
  },
  routes: [
    // ── Shell / root ──────────────────────────────────────────────────────────
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeShell(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const OnboardingPage(),
    ),

    // ── Auth ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/sign-in',
      builder: (_, __) => const SignInPage(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (_, __) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/email-verification',
      builder: (_, __) => const EmailVerificationPage(),
    ),

    // ── Notifications ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationCentrePage(),
    ),
    GoRoute(
      path: '/notifications/prefs',
      builder: (_, __) => const NotificationPrefsPage(),
    ),

    // ── Projects ──────────────────────────────────────────────────────────────
    GoRoute(
      path: '/projects/create',
      builder: (_, __) => const CreateProjectPage(),
    ),
    GoRoute(
      path: '/projects/:id',
      builder: (_, state) => ProjectDetailsPage(
        projectId: state.pathParameters['id']!,
        projectTitle: state.extra as String? ?? '',
      ),
    ),
    GoRoute(
      path: '/projects/:id/edit',
      builder: (_, state) => EditProjectPage(
        project: state.extra as Project,
      ),
    ),
    GoRoute(
      path: '/projects/:id/invoice',
      builder: (_, state) => InvoicePage(
        project: state.extra as Project,
      ),
    ),
    GoRoute(
      path: '/projects/:id/labor',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return LaborTrackingPage(
          projectId: state.pathParameters['id']!,
          projectTitle: extra['projectTitle'] as String? ?? '',
          isOwner: extra['isOwner'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: '/projects/:id/snag',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return SnagListPage(
          projectId: state.pathParameters['id']!,
          projectTitle: extra['projectTitle'] as String? ?? '',
          isOwner: extra['isOwner'] as bool? ?? false,
          isBuilder: extra['isBuilder'] as bool? ?? false,
          assignedBuilderUid: extra['assignedBuilderUid'] as String? ?? '',
          assignedBuilderName: extra['assignedBuilderName'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/projects/:id/site-visits',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return SiteVisitsPage(
          projectId: state.pathParameters['id']!,
          projectTitle: extra['projectTitle'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/projects/:id/variation-orders',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return VariationOrdersPage(
          projectId: state.pathParameters['id']!,
          projectTitle: extra['projectTitle'] as String? ?? '',
          projectBudgetGhs:
              (extra['projectBudgetGhs'] as num?)?.toDouble() ?? 0.0,
        );
      },
    ),
    GoRoute(
      path: '/projects/:id/due-diligence',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return LandOwnershipPage(
          projectId: state.pathParameters['id']!,
          projectTitle: extra['projectTitle'] as String? ?? '',
          isOwner: extra['isOwner'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: '/projects/:id/quotes',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ProjectQuotesPage(
          projectId: state.pathParameters['id']!,
          projectTitle: extra['projectTitle'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/projects/:id/quote-comparison',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return QuoteComparisonPage(
          projectTitle: extra['projectTitle'] as String? ?? '',
          rfqs: extra['rfqs'] as List<RfqRequest>? ?? [],
        );
      },
    ),
    GoRoute(
      path: '/projects/:id/templates',
      builder: (_, __) => const ProjectTemplatesPage(),
    ),
    GoRoute(
      path: '/projects/:id/audit',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ProjectAuditPage(
          projectId: state.pathParameters['id']!,
          projectTitle: extra['projectTitle'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/projects/:id/contract/create',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return CreateContractPage(
          projectId: state.pathParameters['id']!,
          projectTitle: extra['projectTitle'] as String? ?? '',
          builder: extra['builder'] as BuilderProfile,
          ownerUid: extra['ownerUid'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/projects/:id/contract/view',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ContractViewPage(
          contract: extra['contract'] as BuilderContract,
          currentUserUid: extra['currentUserUid'] as String? ?? '',
          signerName: extra['signerName'] as String? ?? '',
        );
      },
    ),

    // ── Estimate ──────────────────────────────────────────────────────────────
    GoRoute(
      path: '/estimate/result',
      builder: (_, __) => const EstimateResultPage(),
    ),
    GoRoute(
      path: '/estimate/saved',
      builder: (_, __) => const SavedEstimatesPage(),
    ),

    // ── People ────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/people/builder/:id',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return BuilderProfileDetailPage(
          builder: extra['builder'] as BuilderProfile,
        );
      },
    ),

    // ── Account ───────────────────────────────────────────────────────────────
    GoRoute(
      path: '/account/edit',
      builder: (_, __) => const EditProfilePage(),
    ),
    GoRoute(
      path: '/account/profile/builder',
      builder: (_, __) => const BuilderProfilePage(),
    ),
    GoRoute(
      path: '/account/profile/pm',
      builder: (_, __) => const PmProfilePage(),
    ),
    GoRoute(
      path: '/account/contracts/pending',
      builder: (_, __) => const PendingContractsPage(),
    ),
    GoRoute(
      path: '/account/rfq-inbox',
      builder: (_, state) => VendorRfqInboxPage(
        vendorId: state.extra as String? ?? '',
      ),
    ),

    // ── Upgrade / Plans ───────────────────────────────────────────────────────
    GoRoute(
      path: '/account/upgrade',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return UpgradePage(
          requiredTier: extra?['tier'] != null
              ? SubscriptionTierInfo.fromString(extra!['tier'] as String?)
              : null,
          featureName: extra?['feature'] as String?,
        );
      },
    ),

    // ── Legal ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/legal',
      builder: (_, state) => LegalPage(
        initialTab: state.uri.queryParameters['tab'] == 'terms' ? 1 : 0,
      ),
    ),

    // ── Complaints ────────────────────────────────────────────────────────────
    GoRoute(
      path: '/complaints',
      builder: (_, __) => const ComplaintsPage(),
    ),

    // ── Vendors ───────────────────────────────────────────────────────────────
    GoRoute(
      path: '/vendors',
      builder: (_, state) => VendorsPage(
        initialRegion: state.extra as String?,
      ),
    ),

    // ── Admin ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminPage(),
    ),
    GoRoute(
      path: '/admin/audit',
      builder: (_, __) => const AuditAdminPage(),
    ),
    GoRoute(
      path: '/admin/boq-rates',
      builder: (_, __) => const BoqRatesAdminPage(),
    ),
    GoRoute(
      path: '/admin/catalog',
      builder: (_, __) => const CatalogAdminPage(),
    ),
    GoRoute(
      path: '/admin/site-visits',
      builder: (_, __) => const SiteVisitsAdminPage(),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (_, __) => const UsersAdminPage(),
    ),
    GoRoute(
      path: '/admin/variation-orders',
      builder: (_, __) => const VariationOrdersAdminPage(),
    ),
    GoRoute(
      path: '/admin/complaints',
      builder: (_, __) => const ComplaintsAdminPage(),
    ),
    GoRoute(
      path: '/admin/deletion-requests',
      builder: (_, __) => const DeletionRequestsAdminPage(),
    ),
    GoRoute(
      path: '/admin/id-verification',
      builder: (_, __) => const IdVerificationAdminPage(),
    ),
    GoRoute(
      path: '/admin/licence-verification',
      builder: (_, __) => const LicenceVerificationAdminPage(),
    ),

    // ── OTP verification ─────────────────────────────────────────────────────
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return OtpVerificationPage(
          phone: extra['phone'] as String? ?? '',
          verificationId: extra['verificationId'] as String? ?? '',
        );
      },
    ),

    // ── Account — Identity ────────────────────────────────────────────────────
    GoRoute(
      path: '/account/id-verification',
      builder: (_, __) => const IdVerificationPage(),
    ),
    GoRoute(
      path: '/account/work-history',
      builder: (_, __) => const WorkExperiencePage(),
    ),
    GoRoute(
      path: '/account/certifications',
      builder: (_, __) => const CertificationsPage(),
    ),
    GoRoute(
      path: '/account/login-activity',
      builder: (_, __) => const LoginActivityPage(),
    ),
    GoRoute(
      path: '/account/portfolio',
      builder: (_, __) => const PortfolioPage(),
    ),

    // ── Project Invitation / Join ──────────────────────────────────────────────
    GoRoute(
      path: '/join',
      builder: (_, state) => JoinProjectPage(
        token: state.uri.queryParameters['token'] ?? '',
      ),
    ),
  ],
);

