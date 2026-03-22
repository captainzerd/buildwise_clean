import 'package:flutter/material.dart';

import 'builder_marketplace_page.dart';
import 'pm_marketplace_page.dart';

/// Tab-based wrapper combining Builders and Project Managers marketplaces.
/// No Scaffold/AppBar — HomeShell provides the AppBar.
class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Builders'),
              Tab(text: 'Project Managers'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                BuilderMarketplacePage(),
                PmMarketplacePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
