#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
final class DraftSnapshot {
  final int schema;
  final String orderId;
  final String baselineTitle;
  final String title;
  const DraftSnapshot({
    required this.schema,
    required this.orderId,
    required this.baselineTitle,
    required this.title,
  });

  bool get isDirty => title.trim() != baselineTitle.trim();
  Map<String, Object> encode() => <String, Object>{
        'schema': schema,
        'orderId': orderId,
        'baselineTitle': baselineTitle,
        'title': title,
      };

  static DraftSnapshot decode(Map<String, Object?> value) {
    if (value['schema'] != 1 ||
        value['orderId'] is! String ||
        value['baselineTitle'] is! String ||
        value['title'] is! String) {
      throw const FormatException('unsupported draft snapshot');
    }
    return DraftSnapshot(
      schema: 1,
      orderId: value['orderId']! as String,
      baselineTitle: value['baselineTitle']! as String,
      title: value['title']! as String,
    );
  }
}

sealed class PageResult {
  const PageResult();
}

final class Saved extends PageResult {
  final String id;
  const Saved(this.id);
}

final class Cancelled extends PageResult {
  const Cancelled();
}

final class NavigationModel {
  final List<String> stack;
  NavigationModel() : stack = <String>['root', 'orders'];
  void openDetail(String id) => stack.add('detail:$id');
  void openEdit(String id) => stack.add('edit:$id');
  PageResult finishEdit(PageResult result) {
    if (!stack.last.startsWith('edit:')) throw StateError('editor not on top');
    stack.removeLast();
    return result;
  }
  void logout() {
    stack
      ..clear()
      ..addAll(<String>['root', 'login']);
  }
}

void main() {
  var assertions = 0;
  void expect(bool condition, String label) {
    assertions++;
    if (!condition) throw StateError(label);
  }

  final nav = NavigationModel();
  nav.openDetail('WO-7');
  nav.openEdit('WO-7');
  expect(nav.stack.join('/') == 'root/orders/detail:WO-7/edit:WO-7',
      'list-detail-edit matrix');
  final saved = nav.finishEdit(const Saved('WO-7'));
  expect(saved is Saved && saved.id == 'WO-7', 'saved result contract');
  expect(nav.stack.last == 'detail:WO-7', 'save pops exactly editor');

  const clean = DraftSnapshot(
      schema: 1, orderId: 'WO-7', baselineTitle: '漏油', title: ' 漏油 ');
  expect(!clean.isDirty, 'normalization avoids false dirty');
  const dirty = DraftSnapshot(
      schema: 1, orderId: 'WO-7', baselineTitle: '漏油', title: '漏油严重');
  expect(dirty.isDirty, 'changed draft blocks back');
  final restored = DraftSnapshot.decode(dirty.encode());
  expect(restored.orderId == 'WO-7' && restored.title == '漏油严重',
      'versioned restoration round trip');

  var rejected = false;
  try {
    DraftSnapshot.decode(<String, Object?>{'schema': 2});
  } on FormatException {
    rejected = true;
  }
  expect(rejected, 'unknown restoration schema rejected');
  nav.logout();
  expect(nav.stack.join('/') == 'root/login', 'logout clears protected stack');
  const Object cancellation = Cancelled();
  expect(cancellation is PageResult, 'explicit cancellation result');
  print('FLUTTER_NAVIGATION_FORMS_LAB_PASS assertions=$assertions faults=3');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
