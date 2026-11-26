import 'package:flutter/material.dart';

/// Root messenger used by non-widget services (download and export feedback)
/// and by the diagnostic probe to show a toast without a page context.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
