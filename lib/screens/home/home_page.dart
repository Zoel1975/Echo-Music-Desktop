
import 'package:expressive_refresh/expressive_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/core/utils/service_locator.dart';
import 'package:Echo/screens/home/cubit/home_cubit.dart';
import 'package:Echo/core/widgets/section_item.dart';
import 'package:Echo/services/home_sections.dart';
import 'package:Echo/utils/internet_guard.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../themes/text_styles.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(sl())..fetch(),
      child: _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    // Import hive at the top
    final box = Hive.box('SETTINGS');
    final hasSeenSupport = box.get('has_seen_support_dialog', defaultValue: false);
    
    if (!hasSeenSupport) {
      // Wait for the frame to build before showing dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSupportDialog();
      });
      await box.put('has_seen_support_dialog', true);
    }
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Echo Music'),
        content: const Text(
          'This app requires time and hard work to develop and maintain. '
          'If you enjoy using Echo Music, please consider supporting the developer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final uri = Uri.parse('https://support.iad1tya.cyou/');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Support'),
          ),
        ],
      ),
    );
  }

  Future<void> _scrollListener() async {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      await context.read<HomeCubit>().fetchNext();
    }
  }

  // Future<void> refresh() async {
  //   if (initialLoading) return;
  //   Map<String, dynamic> home = await ytMusic.browse();
  //   if (mounted) {
  //     setState(() {
  //       initialLoading = false;
  //       nextLoading = false;
  //       chips = home['chips'] ?? [];
  //       sections = home['sections'];
  //       continuation = home['continuation'];
  //     });
  //   }
  // }

  Widget _horizontalChipsRow(List data) {
    var list = <Widget>[const SizedBox(width: 16)];
    for (var element in data) {
      list.add(
        AdaptiveInkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go('/chip', extra: element),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10)),
            child: Text(element['title']),
          ),
        ),
      );
      list.add(const SizedBox(
        width: 8,
      ));
    }
    list.add(const SizedBox(
      width: 8,
    ));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list,
      ),
    );
  }

  /// Lets the user pick which sections appear on Home and in which order,
  /// e.g. liked songs / playlists instead of Billboard charts.
  Future<void> _customizeHome(BuildContext context) async {
    var config = HomeSectionsConfig.load();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Personalizza la home'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final kind in HomeSectionKind.values)
                  ListTile(
                    leading: Icon(kind.icon),
                    title: Text(kind.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (config.isEnabled(kind)) ...[
                          IconButton(
                            tooltip: 'Sposta su',
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: () => setState(
                                () => config = config.move(kind, -1)),
                          ),
                          IconButton(
                            tooltip: 'Sposta giù',
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: () => setState(
                                () => config = config.move(kind, 1)),
                          ),
                        ],
                        Switch(
                          value: config.isEnabled(kind),
                          onChanged: (_) =>
                              setState(() => config = config.toggle(kind)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await config.save();
      if (context.mounted) context.read<HomeCubit>().fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InternetGuard(
      onInternetRestored: context.read<HomeCubit>().fetch,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: AppBar().preferredSize,
          child: AppBar(
            automaticallyImplyLeading: false,
            title: Text(
              'Echo Music',
              style: appBarTitleStyle(),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Personalizza home',
                icon: const Icon(Icons.dashboard_customize),
                onPressed: () => _customizeHome(context),
              ),
            ],
          ),
        ),
        body: ExpressiveRefreshIndicator(
          onRefresh: context.read<HomeCubit>().refresh,
          child: BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              switch (state) {
                case HomeLoading():
                  return Center(
                    child: LoadingIndicatorM3E(),
                  );
                case HomeError():
                  return Center(
                    child: Text(state.message ?? ''),
                  );
                case HomeSuccess():
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    controller: _scrollController,
                    child: SafeArea(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _horizontalChipsRow(state.chips),
                        Column(
                          children: [
                            ...state.sections.map((section) {
                              return SectionItem(section: section);
                            }),
                            if (!state.loadingMore &&
                                state.continuation != null)
                              const SizedBox(height: 50),
                            if (state.loadingMore)
                              const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: ExpressiveLoadingIndicator()),
                          ],
                        ),
                      ],
                    )),
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}