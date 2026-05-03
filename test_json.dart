import 'dart:convert';
import 'dart:io';

void main() {
  try {
    final content = File('assets/data/region8_complete.json').readAsStringSync();
    jsonDecode(content);
    print('✓ JSON is valid');
  } catch (e) {
    print('✗ JSON ERROR: $e');
  }
}
