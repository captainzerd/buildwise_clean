import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/errors/app_exception.dart';
import '../../core/models/builder_contract.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/contract_service.dart';
import '../../core/widgets/empty_state.dart';

class PendingContractsPage extends StatefulWidget {
  const PendingContractsPage({super.key});

  @override
  State<PendingContractsPage> createState() => _PendingContractsPageState();
}

class _PendingContractsPageState extends State<PendingContractsPage> {
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final service = sl<ContractService>();
    final uid = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Contracts')),
      body: StreamBuilder<List<BuilderContract>>(
        stream: service.pendingForBuilder(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load contracts',
              message: AppException.from(snap.error!).message,
              actionLabel: 'Retry',
              onAction: () => setState(() {}),
            );
          }
          final contracts = snap.data ?? [];
          if (contracts.isEmpty) {
            return const EmptyState(
              icon: Icons.description_outlined,
              title: 'No pending contracts',
              message:
                  'Contracts sent to you by project owners will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: contracts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ContractCard(
              contract: contracts[i],
              currentUserUid: uid,
            ),
          );
        },
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  const _ContractCard({
    required this.contract,
    required this.currentUserUid,
  });
  final BuilderContract contract;
  final String currentUserUid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('d MMM yyyy');
    final moneyFmt = NumberFormat('#,##0');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/projects/${contract.projectId}/contract/view',
          extra: {
            'contract': contract,
            'currentUserUid': currentUserUid,
            'signerName':
                context.read<AuthService>().currentUser?.displayName ?? '',
          },
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contract.projectTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3,),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Action required',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'GHS ${moneyFmt.format(contract.totalAmountGhs)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.primary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                contract.scope,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: cs.outline,),
                  const SizedBox(width: 4),
                  Text(
                    'Received ${fmt.format(contract.createdAt)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: cs.outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
