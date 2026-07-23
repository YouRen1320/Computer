import 'package:factorycare_toolchain_example/work_order_label.dart';

void main() {
  final label = formatWorkOrderLabel(id: 'WO-1001', status: 'CREATED');
  print('DART_TOOLCHAIN_EXAMPLE_PASS label=$label');
}
