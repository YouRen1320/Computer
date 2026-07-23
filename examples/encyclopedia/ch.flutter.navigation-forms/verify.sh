#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
sealed class AppRoute {
  const AppRoute();
}

final class OrderListRoute extends AppRoute {
  const OrderListRoute();
}

final class OrderEditRoute extends AppRoute {
  final String orderId;
  const OrderEditRoute(this.orderId);
}

final class UnknownRoute extends AppRoute {
  final Uri uri;
  const UnknownRoute(this.uri);
}

sealed class EditResult {
  const EditResult();
}

final class OrderSaved extends EditResult {
  final String orderId;
  const OrderSaved(this.orderId);
}

final class EditCancelled extends EditResult {
  const EditCancelled();
}

AppRoute parseRoute(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length == 1 && segments.first == 'orders') {
    return const OrderListRoute();
  }
  if (segments.length == 3 &&
      segments[0] == 'orders' &&
      segments[2] == 'edit' &&
      RegExp(r'^WO-[0-9]+$').hasMatch(segments[1])) {
    return OrderEditRoute(segments[1]);
  }
  return UnknownRoute(uri);
}

String? validateTitle(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return 'required';
  if (normalized.length > 20) return 'too-long';
  return null;
}

final class RouteStack {
  final List<AppRoute> _routes = <AppRoute>[const OrderListRoute()];
  int get depth => _routes.length;
  AppRoute get top => _routes.last;
  void push(AppRoute route) => _routes.add(route);
  EditResult popEdit(EditResult result) {
    if (_routes.last is! OrderEditRoute) throw StateError('top is not editor');
    _routes.removeLast();
    return result;
  }
}

void main() {
  var assertions = 0;
  void check(bool condition, String label) {
    assertions++;
    if (!condition) throw StateError(label);
  }

  final edit = parseRoute(Uri.parse('https://factorycare.test/orders/WO-42/edit'));
  check(edit is OrderEditRoute, 'typed deep-link route');
  check((edit as OrderEditRoute).orderId == 'WO-42', 'validated route argument');
  check(parseRoute(Uri.parse('https://factorycare.test/orders')) is OrderListRoute,
      'list route');
  check(parseRoute(Uri.parse('https://factorycare.test/orders/bad/edit')) is UnknownRoute,
      'untrusted id rejected');
  check(validateTitle('  泵体异响  ') == null, 'valid form value');
  check(validateTitle('   ') == 'required', 'blank form value');
  check(validateTitle('123456789012345678901') == 'too-long', 'length boundary');

  final stack = RouteStack()..push(edit);
  check(stack.depth == 2 && stack.top is OrderEditRoute, 'push changes stack');
  final result = stack.popEdit(const OrderSaved('WO-42'));
  check(result is OrderSaved && result.orderId == 'WO-42', 'typed result');
  check(stack.depth == 1 && stack.top is OrderListRoute, 'pop restores list');
  print('FLUTTER_NAVIGATION_FORMS_EXAMPLE_PASS assertions=$assertions');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
