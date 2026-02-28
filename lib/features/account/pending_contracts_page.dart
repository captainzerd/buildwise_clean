import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/builder_contract.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/contract_service.dart';
import '../project/contract_view_page.dart';

class PendingContractsPage extends StatelessWidget {
  const PendingContractsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final service = context.read<ContractService>();
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
            return Center(child: Text('Error: ${snap.error}'));
          }
          final contracts = snap.data ?? [];
          if (contracts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pending contracts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contracts sent to you by project owners will appear here.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: contracts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ContractCard(
              contract: contracts[i],
              currentUserUid: uid,
              contractService: service,
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
    required this.contractService,
  });
  final BuilderContract contract;
  final String currentUserUid;
  final ContractService contractService;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('d MMM yyyy');
    final moneyFmt = NumberFormat('#,##0');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ContractViewPage(
              contract: contract,
              currentUserUid: currentUserUid,
              contractService: contractService,
            ),
          ),
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
