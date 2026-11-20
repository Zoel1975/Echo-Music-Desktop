import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import 'package:Echo/core/utils/service_locator.dart';
import 'package:Echo/core/widgets/section_item.dart';
import 'package:Echo/screens/browse/cubit/browse_cubit.dart';

/// Desktop port of Android's Explore/MusicFlow (Resso-style vertical swipe
/// discovery — see `ui/screens/musicflow/*` on Android). The desktop
/// equivalent is a discoverable scrollable feed of the YouTube Music "Home"
/// (`FEmusic_home`) — see Phase 9 notes in `docs/PORTING_PLAN.md`.
///
/// Android's `MusicFlowScreen` uses `YouTube`'s mix/automix radio; the desktop
/// uses `BrowseCubit` with the same endpoint.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          BrowseCubit(sl(), endpoint: {'browseId': 'FEmusic_home'})..fetch(),
      child: const _ExplorePage(),
    );
  }
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BrowseCubit, BrowseState>(
      builder: (context, state) {
        switch (state) {
          case BrowseLoading():
            return const Scaffold(
              body: Center(child: LoadingIndicatorM3E()),
            );
          case BrowseError(:final message):
            return Scaffold(body: Center(child: Text(message ?? '')));
          case BrowseSuccess(:final header, :final sections):
            return Scaffold(
              appBar: AppBar(
                title: const Text('Explore'),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.new_releases),
                    tooltip: 'New releases',
                    onPressed: () => context.push('/new_releases'),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (final section in sections)
                      if ((section['contents'] as List?)?.isNotEmpty == true)
                        SectionItem(section: section),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}
