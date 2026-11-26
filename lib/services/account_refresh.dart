import 'package:flutter/foundation.dart';

/// Bumped whenever the signed-in account changes (login/logout). Data-loading
/// cubits listen to this to refetch with the new session instead of showing
/// stale anonymous content.
final ValueNotifier<int> accountEpoch = ValueNotifier<int>(0);

void notifyAccountChanged() => accountEpoch.value++;
