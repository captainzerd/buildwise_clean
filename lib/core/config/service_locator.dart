// lib/core/config/service_locator.dart
//
// GetIt service locator — registers all app services as lazy singletons.
// ChangeNotifier services are also provided via MultiProvider in main.dart
// for reactivity; plain service reads use sl<T>() directly.

import 'package:get_it/get_it.dart';

import '../services/audit_service.dart';
import '../services/invitation_service.dart';
import '../services/auth_service.dart';
import '../services/boq_service.dart';
import '../services/builder_profile_service.dart';
import '../services/certification_service.dart';
import '../services/id_verification_service.dart';
import '../services/login_activity_service.dart';
import '../services/work_experience_service.dart';
import '../services/catalog_service.dart';
import '../services/chat_service.dart';
import '../services/complaint_service.dart';
import '../services/connectivity_service.dart';
import '../services/contract_service.dart';
import '../services/csv_service.dart';
import '../services/deletion_request_service.dart';
import '../services/due_diligence_service.dart';
import '../services/fx_service.dart';
import '../services/labor_service.dart';
import '../services/notification_service.dart';
import '../services/payment_service.dart';
import '../services/paystack_service.dart';
import '../services/stripe_service.dart';
import '../services/pdf_service.dart';
import '../services/pm_profile_service.dart';
import '../services/project_service.dart';
import '../services/project_template_service.dart';
import '../services/regional_index_provider.dart';
import '../services/rfq_service.dart';
import '../services/site_visit_service.dart';
import '../services/snag_service.dart';
import '../services/sync_service.dart';
import '../services/task_service.dart';
import '../services/risk_service.dart';
import '../services/land_ownership_service.dart';
import '../services/portfolio_service.dart';
import '../services/receipt_service.dart';
import '../services/variation_order_service.dart';
import '../services/vendor_service.dart';
import '../state/builder_project_state.dart';
import '../state/theme_mode_controller.dart';
import '../storage/offline_queue_store.dart';
import '../storage/storage_service.dart';
import '../../features/estimate/state/estimate_controller.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── Plain class services ──
  sl.registerLazySingleton<StorageService>(() => StorageService());
  sl.registerLazySingleton<ProjectService>(() => ProjectService());
  sl.registerLazySingleton<ChatService>(() => ChatService());
  sl.registerLazySingleton<PaymentService>(() => PaymentService());
  sl.registerLazySingleton<ContractService>(() => ContractService());
  sl.registerLazySingleton<DeletionRequestService>(() => DeletionRequestService());
  sl.registerLazySingleton<RfqService>(() => RfqService());
  sl.registerLazySingleton<AuditService>(() => AuditService());
  sl.registerLazySingleton<PdfService>(() => PdfService());
  sl.registerLazySingleton<CsvService>(() => CsvService());
  sl.registerLazySingleton<DueDiligenceService>(() => DueDiligenceService());
  sl.registerLazySingleton<SnagService>(() => SnagService());
  sl.registerLazySingleton<LaborService>(() => LaborService());
  sl.registerLazySingleton<SiteVisitService>(() => SiteVisitService());
  sl.registerLazySingleton<PaystackService>(() => PaystackService());
  sl.registerLazySingleton<StripeService>(() => StripeService());
  sl.registerLazySingleton<ProjectTemplateService>(() => ProjectTemplateService());
  sl.registerLazySingleton<ComplaintService>(() => ComplaintService());
  sl.registerLazySingleton<WorkExperienceService>(() => WorkExperienceService());
  sl.registerLazySingleton<CertificationService>(() => CertificationService());
  sl.registerLazySingleton<IdVerificationService>(() => IdVerificationService());
  sl.registerLazySingleton<LoginActivityService>(() => LoginActivityService());
  sl.registerLazySingleton<TaskService>(() => TaskService());
  sl.registerLazySingleton<RiskService>(() => RiskService());
  sl.registerLazySingleton<LandOwnershipService>(() => LandOwnershipService());
  sl.registerLazySingleton<PortfolioService>(() => PortfolioService());
  sl.registerLazySingleton<ReceiptService>(() => ReceiptService());
  sl.registerLazySingleton<InvitationService>(
    () => InvitationService(projectService: sl<ProjectService>()),
  );

  // ── ChangeNotifier services ──
  sl.registerLazySingleton<AuthService>(() => AuthService());
  sl.registerLazySingleton<CatalogService>(() => CatalogService());
  sl.registerLazySingleton<RegionalIndexProvider>(
    () => RegionalIndexProvider(catalogService: sl<CatalogService>()),
  );
  sl.registerLazySingleton<FxService>(() => FxService());
  sl.registerLazySingleton<BuilderProfileService>(() => BuilderProfileService());
  sl.registerLazySingleton<PmProfileService>(() => PmProfileService());
  sl.registerLazySingleton<VendorService>(() => VendorService());
  sl.registerLazySingleton<VariationOrderService>(() => VariationOrderService());
  sl.registerLazySingleton<ThemeModeController>(() => ThemeModeController());
  sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
  sl.registerLazySingleton<OfflineQueueStore>(() => OfflineQueueStore());
  sl.registerLazySingleton<SyncService>(
    () => SyncService(
      connectivity: sl<ConnectivityService>(),
      queue: sl<OfflineQueueStore>(),
      projectService: sl<ProjectService>(),
      paymentService: sl<PaymentService>(),
    ),
  );
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<BoqService>(() => BoqService());
  sl.registerLazySingleton<EstimateController>(
    () => EstimateController(
      catalogService: sl<CatalogService>(),
      regionalIndexProvider: sl<RegionalIndexProvider>(),
      fxService: sl<FxService>(),
      storageService: sl<StorageService>(),
    ),
  );
  sl.registerLazySingleton<BuilderProjectState>(() => BuilderProjectState());
}
