import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/auth/data/models/gym_member_model.dart';
import '../../features/auth/data/models/gym_tenant_model.dart';
import 'member_qr_service.dart';

class ICardGenerator {
  /// Generates the PDF document for member I-Card with front and back passes.
  /// Matches the luxury gold and black curved aesthetic with gym branding from Firebase.
  static Future<pw.Document> generateICardDocument({
    required GymMemberModel member,
    GymTenantModel? tenant,
    String? customLogoUrl,
  }) async {
    final pdf = pw.Document();

    const pageFormat = PdfPageFormat(153 * 1.5, 243 * 1.5, marginAll: 8);

    // Get gym details and colors
    String? tenantLogoUrl = customLogoUrl ?? tenant?.logoUrl;
    String gymName = tenant?.gymName ?? 'ABSOLUTE FIT';
    String gymAddress =
        tenant?.address ?? 'Samad Ali Shopping Complex Kralpora';
    String gymPhone = tenant?.phone ?? '7006167204';

    // 1. Fetch from Firebase Firestore if logoUrl is missing or tenant was not fully loaded
    final effectiveTenantId = tenant?.id ?? member.tenantId;
    if ((tenantLogoUrl == null || tenantLogoUrl.isEmpty) &&
        effectiveTenantId != null &&
        effectiveTenantId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('tenants')
            .doc(effectiveTenantId)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final fetchedLogo = data['logoUrl'] as String?;
            if (fetchedLogo != null && fetchedLogo.isNotEmpty) {
              tenantLogoUrl = fetchedLogo;
            }
            if ((tenant == null || tenant.gymName.isEmpty) &&
                data['gymName'] != null) {
              gymName = data['gymName'] as String;
            }
            if ((tenant == null || tenant.address.isEmpty) &&
                data['address'] != null) {
              gymAddress = data['address'] as String;
            }
            if ((tenant == null || tenant.phone == null) &&
                data['phone'] != null) {
              gymPhone = data['phone'] as String;
            }
          }
        }
      } catch (e) {
        // Fallback gracefully if Firestore is unavailable or uninitialized
      }
    }

    // 2. Load Gym Logo from Firebase URL (with fallback to local asset)
    pw.ImageProvider? gymLogoImage;
    if (tenantLogoUrl != null && tenantLogoUrl.isNotEmpty) {
      try {
        gymLogoImage = await networkImage(tenantLogoUrl);
      } catch (e) {
        // Network fetch error or offline, fallback to bundled logo asset
      }
    }

    // Bundled fallback logo if Firebase image failed to load or is not yet set
    gymLogoImage ??= await _loadLocalOrAssetImage('assets/images/logo.png');

    // 3. Load Gym Background Images (Front header dumbbells, front bottom muscles, back header workout)
    final frontHeaderBgImage =
        await _loadLocalOrAssetImage('assets/images/icard_bg_front_header.jpg');
    final frontMusclesBgImage = await _loadLocalOrAssetImage(
        'assets/images/icard_bg_front_muscles.jpg');
    final backHeaderBgImage =
        await _loadLocalOrAssetImage('assets/images/icard_bg_back_header.jpg');

    // Attempt to load member avatar
    pw.ImageProvider? avatarImage;
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      try {
        avatarImage = await networkImage(member.photoUrl!);
      } catch (e) {
        // Ignored
      }
    }

    // Standard Luxury Gold Colors
    const goldColor = PdfColor.fromInt(0xFFC59B27);
    const cardBorderColor = PdfColor.fromInt(0xFFD8DEE8);
    const textDarkColor = PdfColor.fromInt(0xFF11141A);
    const textMutedColor = PdfColor.fromInt(0xFF757B88);

    // Format display member ID to match screenshot style: MEM_1790
    String displayId = member.id.toUpperCase();
    if (displayId.startsWith('MEM_')) {
      // Already formatted
    } else if (displayId.startsWith('MEM')) {
      displayId = 'MEM_${displayId.substring(3)}';
    } else {
      displayId = 'MEM_$displayId';
    }
    if (displayId.length > 12) {
      displayId = displayId.substring(0, 12);
    }

    // Front Side
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
              border: pw.Border.all(color: cardBorderColor, width: 0.9),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 14,
              verticalRadius: 14,
              child: pw.Stack(
                children: [
                  // Top Header Gym Equipment Background Image
                  if (frontHeaderBgImage != null)
                    pw.Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: pw.SizedBox(
                        height: 92,
                        child: pw.Image(
                          frontHeaderBgImage,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),

                  // Bottom Muscular Silhouette and Dark Container
                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.Container(
                      height: 84,
                      color: const PdfColor.fromInt(0xFF090B0F),
                    ),
                  ),
                  if (frontMusclesBgImage != null)
                    pw.Positioned(
                      bottom: 0,
                      right: 0,
                      child: pw.SizedBox(
                        width: 125,
                        height: 84,
                        child: pw.Image(
                          frontMusclesBgImage,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),

                  // Top Dark Wave with Golden Ribbon
                  pw.Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: pw.SvgImage(
                      svg: _frontTopWaveSvg(),
                      fit: pw.BoxFit.fill,
                      height: 104,
                      width: 214,
                    ),
                  ),

                  // Bottom Dark Wave with Golden Ribbon
                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.SvgImage(
                      svg: _frontBottomWaveSvg(),
                      fit: pw.BoxFit.fill,
                      height: 84,
                      width: 214,
                    ),
                  ),

                  // Top Header: Gym Logo with Gold Ring & Gym Name
                  pw.Positioned(
                    top: 10,
                    left: 14,
                    right: 14,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Circular Gym Logo with Gold Ring
                        pw.Container(
                          width: 36,
                          height: 36,
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColors.black,
                            border: pw.Border.all(color: goldColor, width: 2.2),
                          ),
                          child: pw.ClipOval(
                            child: gymLogoImage != null
                                ? pw.Image(gymLogoImage, fit: pw.BoxFit.cover)
                                : pw.Center(
                                    child: pw.Text(
                                      gymName.isNotEmpty
                                          ? gymName[0].toUpperCase()
                                          : 'G',
                                      style: const pw.TextStyle(
                                        color: goldColor,
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        pw.SizedBox(width: 9),
                        // Gym Name & Pass Subtitle
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Text(
                                gymName.toUpperCase(),
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                                style: const pw.TextStyle(
                                  color: goldColor,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'OFFICIAL MEMBER PASS',
                                style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 6.5,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Centered Avatar overlapping top golden ribbon
                  pw.Positioned(
                    top: 66,
                    left: 0,
                    right: 0,
                    child: pw.Center(
                      child: pw.Container(
                        width: 60,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.white,
                          border: pw.Border.all(color: goldColor, width: 3.2),
                          boxShadow: const [
                            pw.BoxShadow(
                              color: PdfColor.fromInt(0x35000000),
                              blurRadius: 5,
                              offset: PdfPoint(0, 2),
                            ),
                          ],
                        ),
                        child: pw.ClipOval(
                          child: avatarImage != null
                              ? pw.Image(avatarImage, fit: pw.BoxFit.cover)
                              : pw.Container(
                                  color: const PdfColor.fromInt(0xFFFBF6EE),
                                  child: pw.Center(
                                    child: pw.Text(
                                      member.firstName.isNotEmpty
                                          ? member.firstName[0].toUpperCase()
                                          : '?',
                                      style: const pw.TextStyle(
                                        fontSize: 26,
                                        fontWeight: pw.FontWeight.bold,
                                        color: goldColor,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  // Member Identity & Information Section
                  pw.Positioned(
                    top: 132,
                    left: 14,
                    right: 14,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Member Full Name
                        pw.Text(
                          member.fullName,
                          style: const pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: textDarkColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),

                        // Gold Pill Badge: Crown + MEMBER
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFFDF4E7),
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(10)),
                            border: pw.Border.all(
                                color: const PdfColor.fromInt(0xFFEED8B6),
                                width: 0.8),
                          ),
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.SvgImage(
                                svg: _crownSvg(),
                                width: 9,
                                height: 9,
                              ),
                              pw.SizedBox(width: 4),
                              pw.Text(
                                member.isLifetimeFree
                                    ? 'LIFETIME MEMBER'
                                    : 'MEMBER',
                                style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: goldColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        pw.SizedBox(height: 12),

                        // Details Rows with Circular Golden Icon Badges
                        _buildModernDetailRow(
                          iconSvg: _idCardIconSvg(),
                          label: 'MEMBER ID',
                          value: displayId,
                          showDivider: true,
                        ),
                        _buildModernDetailRow(
                          iconSvg: _phoneIconSvg(),
                          label: 'PHONE',
                          value: member.phone,
                          showDivider: true,
                        ),
                        _buildModernDetailRow(
                          iconSvg: _layersIconSvg(),
                          label: 'PLAN',
                          value: member.planName.toUpperCase(),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),

                  // Bottom Slogans: STRONGER / HEALTHIER / HAPPIER
                  pw.Positioned(
                    bottom: 12,
                    left: 16,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'STRONGER',
                          style: const pw.TextStyle(
                            color: goldColor,
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.6,
                          ),
                        ),
                        pw.Text(
                          'HEALTHIER',
                          style: const pw.TextStyle(
                            color: goldColor,
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.6,
                          ),
                        ),
                        pw.Text(
                          'HAPPIER',
                          style: const pw.TextStyle(
                            color: goldColor,
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Back Side
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
              border: pw.Border.all(color: cardBorderColor, width: 0.9),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 14,
              verticalRadius: 14,
              child: pw.Stack(
                children: [
                  // Top Header Gym Dumbbell Background Image
                  if (backHeaderBgImage != null)
                    pw.Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: pw.SizedBox(
                        height: 64,
                        child: pw.Image(
                          backHeaderBgImage,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),

                  // Top Dark Wave with Golden Ribbon
                  pw.Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: pw.SvgImage(
                      svg: _backTopWaveSvg(),
                      fit: pw.BoxFit.fill,
                      height: 76,
                      width: 214,
                    ),
                  ),

                  // Bottom Dark Wave with Golden Ribbon
                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.SvgImage(
                      svg: _backBottomWaveSvg(),
                      fit: pw.BoxFit.fill,
                      height: 72,
                      width: 214,
                    ),
                  ),

                  // Centered Gym Logo at Top with Gold Ring
                  pw.Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: pw.Center(
                      child: pw.Container(
                        width: 44,
                        height: 44,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.black,
                          border: pw.Border.all(color: goldColor, width: 2.2),
                        ),
                        child: pw.ClipOval(
                          child: gymLogoImage != null
                              ? pw.Image(gymLogoImage, fit: pw.BoxFit.cover)
                              : pw.Center(
                                  child: pw.Text(
                                    gymName.isNotEmpty
                                        ? gymName[0].toUpperCase()
                                        : 'G',
                                    style: const pw.TextStyle(
                                      color: goldColor,
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  // Return Info Section & QR Code
                  pw.Positioned(
                    top: 80,
                    left: 14,
                    right: 14,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'IF FOUND, PLEASE RETURN TO:',
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            fontWeight: pw.FontWeight.bold,
                            color: textMutedColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          gymName.toUpperCase(),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: goldColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        // Address Row with Pin
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.SvgImage(
                              svg: _pinIconSvg(),
                              width: 7,
                              height: 7,
                            ),
                            pw.SizedBox(width: 3),
                            pw.Flexible(
                              child: pw.Text(
                                gymAddress.replaceAll('\n', ', '),
                                textAlign: pw.TextAlign.center,
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                                style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  color: textDarkColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (gymPhone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.SvgImage(
                                svg: _phoneSmallIconSvg(),
                                width: 7,
                                height: 7,
                              ),
                              pw.SizedBox(width: 3),
                              pw.Text(
                                'Phone: $gymPhone',
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  color: textDarkColor,
                                ),
                              ),
                            ],
                          ),
                        ],

                        pw.SizedBox(height: 10),

                        // QR Code in Gold Frame with Mini Center Logo
                        pw.Container(
                          width: 96,
                          height: 96,
                          padding: const pw.EdgeInsets.all(5),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(10)),
                            border: pw.Border.all(color: goldColor, width: 1.5),
                            boxShadow: const [
                              pw.BoxShadow(
                                color: PdfColor.fromInt(0x1F000000),
                                blurRadius: 4,
                                offset: PdfPoint(0, 2),
                              ),
                            ],
                          ),
                          child: pw.Stack(
                            alignment: pw.Alignment.center,
                            children: [
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: MemberQrService.generateQrPayload(
                                  member: member,
                                  tenantId: tenant?.id ??
                                      member.tenantId ??
                                      'default_tenant',
                                ),
                                drawText: false,
                                color: PdfColors.black,
                              ),
                              // Center Mini Logo with gold ring
                              pw.Container(
                                width: 22,
                                height: 22,
                                decoration: pw.BoxDecoration(
                                  shape: pw.BoxShape.circle,
                                  color: PdfColors.black,
                                  border: pw.Border.all(
                                      color: goldColor, width: 1.2),
                                ),
                                child: pw.ClipOval(
                                  child: gymLogoImage != null
                                      ? pw.Image(gymLogoImage,
                                          fit: pw.BoxFit.cover)
                                      : pw.Center(
                                          child: pw.Text(
                                            gymName.isNotEmpty
                                                ? gymName[0].toUpperCase()
                                                : 'G',
                                            style: const pw.TextStyle(
                                              color: goldColor,
                                              fontSize: 10,
                                              fontWeight: pw.FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        pw.SizedBox(height: 6),

                        // Scan to verify pill
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFFDF4E7),
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(8)),
                            border: pw.Border.all(
                                color: const PdfColor.fromInt(0xFFEED8B6),
                                width: 0.7),
                          ),
                          child: pw.Text(
                            'Scan to verify membership',
                            style: const pw.TextStyle(
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              color: textMutedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom 3 Pillars (TRAIN | PERSIST | GROW)
                  pw.Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        _buildPillarColumn(
                            iconSvg: _dumbbellIconSvg(), label: 'TRAIN'),
                        pw.Container(
                            width: 1,
                            height: 18,
                            color: const PdfColor.fromInt(0xFF5A471C)),
                        _buildPillarColumn(
                            iconSvg: _heartIconSvg(), label: 'PERSIST'),
                        pw.Container(
                            width: 1,
                            height: 18,
                            color: const PdfColor.fromInt(0xFF5A471C)),
                        _buildPillarColumn(
                            iconSvg: _lightningIconSvg(), label: 'GROW'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf;
  }

  /// Generates the I-Card PDF and opens the native printing/preview dialog.
  static Future<void> generateAndPreviewICard({
    required GymMemberModel member,
    GymTenantModel? tenant,
    String? customLogoUrl,
  }) async {
    final pdf = await generateICardDocument(
      member: member,
      tenant: tenant,
      customLogoUrl: customLogoUrl,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ICard_${member.firstName}_${member.lastName}.pdf',
    );
  }

  static pw.Widget _buildModernDetailRow({
    required String iconSvg,
    required String label,
    required String value,
    required bool showDivider,
  }) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: [
              // Circular Gold Icon Badge
              pw.Container(
                width: 20,
                height: 20,
                decoration: const pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColor.fromInt(0xFFF7EBD9),
                ),
                child: pw.Center(
                  child: pw.SvgImage(
                    svg: iconSvg,
                    width: 11,
                    height: 11,
                  ),
                ),
              ),
              pw.SizedBox(width: 9),
              // Label
              pw.Text(
                label,
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF757B88),
                  letterSpacing: 0.5,
                ),
              ),
              pw.Spacer(),
              // Value
              pw.Text(
                value,
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF11141A),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          pw.Container(
            height: 0.6,
            color: const PdfColor.fromInt(0xFFF0EAE1),
            margin: const pw.EdgeInsets.only(left: 29),
          ),
      ],
    );
  }

  static pw.Widget _buildPillarColumn({
    required String iconSvg,
    required String label,
  }) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SvgImage(
          svg: iconSvg,
          width: 13,
          height: 13,
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          label,
          style: const pw.TextStyle(
            color: PdfColor.fromInt(0xFFD4AF37),
            fontSize: 6.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // Helper to load bundled asset or local file bytes (works in tests & production)
  static Future<pw.ImageProvider?> _loadLocalOrAssetImage(
      String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      try {
        final file = File(assetPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }
    return null;
  }

  // ──────── SVG ASSETS & VECTOR PATHS ────────

  static String _frontTopWaveSvg() => '''
<svg viewBox="0 0 214 104" width="214" height="104" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="goldRibbonFrontTop" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#AA7C11" />
      <stop offset="35%" stop-color="#F7E298" />
      <stop offset="65%" stop-color="#D4AF37" />
      <stop offset="100%" stop-color="#C59B27" />
    </linearGradient>
  </defs>
  <!-- Gold ribbon wave border -->
  <path d="M0,72 C38,94 75,76 107,72 C140,68 175,98 214,84 L214,89 C175,103 140,73 107,77 C75,81 38,99 0,77 Z" fill="url(#goldRibbonFrontTop)" />
  <!-- Solid white mask below the gold ribbon -->
  <path d="M0,77 C38,99 75,81 107,77 C140,73 175,103 214,89 L214,104 L0,104 Z" fill="#FFFFFF" />
</svg>''';

  static String _frontBottomWaveSvg() => '''
<svg viewBox="0 0 214 84" width="214" height="84" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="goldRibbonFrontBtm" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#AA7C11" />
      <stop offset="40%" stop-color="#F7E298" />
      <stop offset="70%" stop-color="#D4AF37" />
      <stop offset="100%" stop-color="#C59B27" />
    </linearGradient>
  </defs>
  <!-- Solid white mask above the gold ribbon -->
  <path d="M0,0 L214,0 L214,20 C195,11 175,4 150,14 C100,36 50,2 0,20 Z" fill="#FFFFFF" />
  <!-- Gold ribbon wave border -->
  <path d="M0,20 C50,2 100,36 150,14 C175,4 195,11 214,20 L214,25 C195,16 175,9 150,19 C100,41 50,7 0,25 Z" fill="url(#goldRibbonFrontBtm)" />
</svg>''';

  static String _backTopWaveSvg() => '''
<svg viewBox="0 0 214 76" width="214" height="76" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="goldRibbonBackTop" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#C59B27" />
      <stop offset="35%" stop-color="#F7E298" />
      <stop offset="70%" stop-color="#D4AF37" />
      <stop offset="100%" stop-color="#AA7C11" />
    </linearGradient>
  </defs>
  <!-- Gold ribbon wave border -->
  <path d="M0,48 C18,58 36,66 70,58 C118,52 165,66 214,48 L214,53 C165,71 118,57 70,63 C36,71 18,63 0,53 Z" fill="url(#goldRibbonBackTop)" />
  <!-- Solid white mask below the gold ribbon -->
  <path d="M0,53 C18,63 36,71 70,63 C118,57 165,71 214,53 L214,76 L0,76 Z" fill="#FFFFFF" />
</svg>''';

  static String _backBottomWaveSvg() => '''
<svg viewBox="0 0 214 72" width="214" height="72" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="goldRibbonBackBtm" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#AA7C11" />
      <stop offset="50%" stop-color="#F7E298" />
      <stop offset="100%" stop-color="#C59B27" />
    </linearGradient>
    <linearGradient id="darkBgBackBtm" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#181D26" />
      <stop offset="100%" stop-color="#090B0F" />
    </linearGradient>
  </defs>
  <!-- Solid white mask above the gold ribbon -->
  <path d="M0,0 L214,0 L214,14 C200,7 185,4 165,10 C110,28 45,2 0,15 Z" fill="#FFFFFF" />
  <!-- Gold ribbon wave border -->
  <path d="M0,15 C45,2 110,28 165,10 C185,4 200,7 214,14 L214,19 C200,12 185,9 165,15 C110,33 45,7 0,20 Z" fill="url(#goldRibbonBackBtm)" />
  <!-- Dark bottom wave -->
  <path d="M0,20 C45,7 110,33 165,15 C185,9 200,12 214,19 L214,72 L0,72 Z" fill="url(#darkBgBackBtm)" />
  <!-- Subtle gold stipples/glitter -->
  <circle cx="18" cy="30" r="0.8" fill="#F7E298" opacity="0.6" />
  <circle cx="28" cy="38" r="0.6" fill="#F7E298" opacity="0.4" />
  <circle cx="48" cy="24" r="0.7" fill="#F7E298" opacity="0.5" />
  <circle cx="82" cy="36" r="0.8" fill="#F7E298" opacity="0.6" />
  <circle cx="106" cy="42" r="0.6" fill="#F7E298" opacity="0.5" />
  <circle cx="140" cy="30" r="0.8" fill="#F7E298" opacity="0.6" />
  <circle cx="185" cy="28" r="0.7" fill="#F7E298" opacity="0.5" />
</svg>''';

  static String _crownSvg() => '''
<svg viewBox="0 0 24 24" width="24" height="24" fill="#C59B27">
  <path d="M5 16L3 5l5.5 5L12 4l3.5 6L21 5l-2 11H5zm14 3c0 .6-.4 1-1 1H6c-.6 0-1-.4-1-1v-1h14v1z"/>
</svg>''';

  static String _idCardIconSvg() => '''
<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#C59B27" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2" y="4" width="20" height="16" rx="3"/>
  <circle cx="8" cy="11" r="2.5"/>
  <line x1="13.5" y1="9.5" x2="18.5" y2="9.5"/>
  <line x1="13.5" y1="13.5" x2="18.5" y2="13.5"/>
</svg>''';

  static String _phoneIconSvg() => '''
<svg viewBox="0 0 24 24" width="24" height="24" fill="#C59B27">
  <path d="M6.62 10.79a15.053 15.053 0 006.59 6.59l2.2-2.2a1 1 0 011.02-.24c1.12.37 2.33.57 3.57.57a1 1 0 011 1V20a1 1 0 01-1 1A17 17 0 013 4a1 1 0 011-1h3.5a1 1 0 011 1c0 1.25.2 2.45.57 3.57a1 1 0 01-.25 1.02l-2.2 2.2z"/>
</svg>''';

  static String _layersIconSvg() => '''
<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#C59B27" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <polygon points="12 2 2 7 12 12 22 7 12 2"/>
  <polyline points="2 17 12 22 22 17"/>
  <polyline points="2 12 12 17 22 12"/>
</svg>''';

  static String _pinIconSvg() => '''
<svg viewBox="0 0 24 24" width="24" height="24" fill="#C59B27">
  <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 110-5 2.5 2.5 0 010 5z"/>
</svg>''';

  static String _phoneSmallIconSvg() => '''
<svg viewBox="0 0 24 24" width="24" height="24" fill="#C59B27">
  <path d="M6.62 10.79a15.053 15.053 0 006.59 6.59l2.2-2.2a1 1 0 011.02-.24c1.12.37 2.33.57 3.57.57a1 1 0 011 1V20a1 1 0 01-1 1A17 17 0 013 4a1 1 0 011-1h3.5a1 1 0 011 1c0 1.25.2 2.45.57 3.57a1 1 0 01-.25 1.02l-2.2 2.2z"/>
</svg>''';

  static String _dumbbellIconSvg() => '''
<svg viewBox="0 0 24 24" width="24" height="24" fill="#D4AF37">
  <path d="M6 5H4v14h2V5zm14 0h-2v14h2V5zM2 9H1v6h1V9zm21 0h-1v6h1V9zM7 11h10v2H7v-2z"/>
</svg>''';

  static String _heartIconSvg() => '''
<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#D4AF37" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
</svg>''';

  static String _lightningIconSvg() => '''
<svg viewBox="0 0 24 24" width="24" height="24" fill="#D4AF37">
  <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
</svg>''';
}
