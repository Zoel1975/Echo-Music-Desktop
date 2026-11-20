import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/account_refresh.dart';

void main() {
  test('notifyAccountChanged bumps the epoch so data cubits refetch', () {
    final before = accountEpoch.value;
    var notifications = 0;
    void listener() => notifications++;
    accountEpoch.addListener(listener);
    addTearDown(() => accountEpoch.removeListener(listener));

    notifyAccountChanged();
    expect(accountEpoch.value, before + 1);
    expect(notifications, 1);
  });
}
