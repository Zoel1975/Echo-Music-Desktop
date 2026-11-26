import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back button for sub-pages/menus. Pops the route when there is one to pop,
/// otherwise returns to the app home — so it always works, even when the
/// page was opened with `context.go` from a shell branch.
Widget echoBackButton(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Indietro',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
    );
