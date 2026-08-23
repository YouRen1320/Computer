import 'solution.dart';

void main() {
  const secret = 'token=secret; path=/private/user/photo.jpg';
  final cases = <(NativeFailure, UiKind, String)>[
    (const NativeFailure('denied', secret), UiKind.denied, 'CAMERA_DENIED'),
    (
      const NativeFailure('deniedForever', secret),
      UiKind.settingsRequired,
      'CAMERA_SETTINGS_REQUIRED',
    ),
    (
      const NativeFailure('busy', secret),
      UiKind.failure,
      'DEVICE_PLATFORM_FAILURE',
    ),
  ];
  for (final (failure, kind, code) in cases) {
    final mapped = mapFailure(failure);
    if (mapped.kind != kind || mapped.diagnosticCode != code) {
      throw StateError('mapping ${failure.code}');
    }
    if (mapped.userMessage.contains('token=') ||
        mapped.userMessage.contains('/private/') ||
        mapped.userMessage == failure.message) {
      throw StateError('redaction ${failure.code}');
    }
  }
  print('FLUTTER_DEVICE_APIS_SOLUTION_PASS checks=9 real_device=false');
}
