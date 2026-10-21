import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/services/whatsapp_service.dart';

void main() {
  test('normalizes Indian member numbers for WhatsApp', () {
    expect(normalizeWhatsAppRecipient('9876543210'), '919876543210');
    expect(normalizeWhatsAppRecipient('+91 98765 43210'), '919876543210');
    expect(normalizeWhatsAppRecipient('09876543210'), '919876543210');
    expect(normalizeWhatsAppRecipient('919876543210'), '919876543210');
    expect(normalizeWhatsAppRecipient(''), isNull);
    expect(normalizeWhatsAppRecipient('12345'), isNull);
  });
}
