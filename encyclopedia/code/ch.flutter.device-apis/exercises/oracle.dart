import 'dart:io';

import 'starter.dart';

void main() {
  final problems = <String>[];
  const secret = 'token=secret; path=/private/user/photo.jpg';
  final cases = <(NativeFailure, UiKind, String)>[
    (const NativeFailure('denied', secret), UiKind.denied, 'CAMERA_DENIED'),
    (
      const NativeFailure('deniedForever', secret),
      UiKind.settingsRequired,
      'CAMERA_SETTINGS_REQUIRED',
    ),
    (
      const NativeFailure('platform-busy', secret),
      UiKind.failure,
      'DEVICE_PLATFORM_FAILURE',
    ),
  ];

  for (final (failure, expectedKind, expectedCode) in cases) {
    final mapped = mapFailure(failure);
    if (mapped.kind != expectedKind) problems.add('${failure.code}-kind');
    if (mapped.diagnosticCode != expectedCode) {
      problems.add('${failure.code}-diagnostic-code');
    }
    if (mapped.userMessage.contains('token=') ||
        mapped.userMessage.contains('/private/') ||
        mapped.userMessage == failure.message) {
      problems.add('${failure.code}-raw-message-leak');
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln(
      'EXPECTED_FLUTTER_DEVICE_APIS_RED problems=${problems.join(',')}',
    );
    exitCode = 1;
    return;
  }
  print('FLUTTER_DEVICE_APIS_EXERCISE_PASS checks=9');
}
