
import 'package:expressive_refresh/expressive_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/core/utils/service_locator.dart';
import 'package:Echo/screens/home/cubit/home_cubit.dart';
import 'package:Echo/core/widgets/section_item.dart';
import 'package:Echo/core/theme/motion_tokens.dart';
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
    // Show enabled sections first, in the exact saved order; disabled ones
    // follow. The old dialog used enum order, so toggling/reordering felt
    // inconsistent with what was actually rendered on Home.
    final orderedKinds = <HomeSectionKind>[
      ...config.order,
      ...HomeSectionKind.values.where((k) => !config.isEnabled(k)),
    ];
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
                for (final kind in orderedKinds)
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
      if (context.mounted) context.read<HomeCubit>().refresh();
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
                  return const _HomeSkeleton();
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
                            ...state.sections.asMap().entries.map((entry) {
                              return _AnimatedSection(
                                index: entry.key,
                                child: SectionItem(section: entry.value),
                              );
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

/// One-shot entrance for a home section. Staggered by [index] so sections
/// arrive in reading order instead of all snapping in at once.
class _AnimatedSection extends StatelessWidget {
  const _AnimatedSection({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: (index * 45).clamp(0, 270));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MotionTokens.section + delay,
      curve: MotionTokens.standard,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Skeleton instead of a spinner: the layout is visible immediately, so the
/// feed feels like it is loading *into* the page rather than replacing it.
class _HomeSkeleton extends StatefulWidget {
  const _HomeSkeleton();

  @override
  State<_HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<_HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionTokens.skeleton,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shift = _controller.value * 2 - 1;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _shimmer(120, 32, shift, radius: 16),
            const SizedBox(height: 28),
            ...List.generate(2, (section) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmer(180, 20, shift),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 170,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, __) => _shimmer(130, 160, shift),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                )),
          ],
        );
      },
    );
  }

  Widget _shimmer(double width, double height, double shift, {double radius = 10}) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(shift, 0),
        end: Alignment(shift + 0.8, 0),
        colors: [
          Colors.grey.withValues(alpha: 0.10),
          Colors.grey.withValues(alpha: 0.22),
          Colors.grey.withValues(alpha: 0.10),
        ],
      ).createShader(bounds),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}