import 'package:flutter_test/flutter_test.dart';
import 'package:newchat/core/security/secret_masker.dart';

void main() {
  test('masks long API keys', () {
    expect(maskSecret('sk-abcdefghijklmnopqrstuvwxyz'), 'sk-a...wxyz');
  });

  test('masks short secrets completely', () {
    expect(maskSecret('abc123'), '******');
  });

  test('masks empty secrets', () {
    expect(maskSecret(''), '');
  });
}
