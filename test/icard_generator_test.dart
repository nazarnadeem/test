import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/utils/icard_generator.dart';
import 'package:gcrm_one/features/auth/data/models/gym_member_model.dart';
import 'package:gcrm_one/features/auth/data/models/gym_tenant_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMember = GymMemberModel(
    id: 'MEM12345678',
    tenantId: 'tenant_gym_01',
    firstName: 'Alex',
    lastName: 'Hunter',
    phone: '+91 98765 43210',
    email: 'alex@example.com',
    membershipPlan: 'Gold Annual Pass',
    startDate: DateTime(2025, 1, 1),
    expiryDate: DateTime(2026, 1, 1),
    isActive: true,
  );

  final testTenant = GymTenantModel(
    id: 'tenant_gym_01',
    gymName: 'Titan Elite Fitness',
    ownerId: 'owner_01',
    ownerName: 'Titan Owner',
    ownerEmail: 'owner@titanfitness.com',
    address: '100 Fitness Boulevard, Metro City',
    phone: '+91 80000 11111',
    gymCode: 'TITAN01',
    logoUrl: 'https://example.com/logo.png',
    primaryColorHex: '#10B981',
    createdAt: DateTime(2024, 1, 1),
  );

  test('generateICardDocument generates 2 pages (front and back) with gym details', () async {
    final pdfDoc = await ICardGenerator.generateICardDocument(
      member: testMember,
      tenant: testTenant,
    );

    expect(pdfDoc.document.pdfPageList.pages.length, equals(2));
    final pdfBytes = await pdfDoc.save();
    expect(pdfBytes.length, greaterThan(1000));
  });

  test('generateICardDocument gracefully handles null tenant and missing logo', () async {
    final pdfDoc = await ICardGenerator.generateICardDocument(
      member: testMember,
      tenant: null,
    );

    expect(pdfDoc.document.pdfPageList.pages.length, equals(2));
    final pdfBytes = await pdfDoc.save();
    expect(pdfBytes.length, greaterThan(1000));
  });

  test('verify ClipRRect and ClipOval in pdf', () async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(200, 200),
        build: (context) => pw.ClipRRect(
          horizontalRadius: 10,
          verticalRadius: 10,
          child: pw.ClipOval(
            child: pw.Container(width: 50, height: 50, color: PdfColors.amber),
          ),
        ),
      ),
    );
    final bytes = await pdf.save();
    expect(bytes.length, greaterThan(100));
  });
}
