import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/image_optimizer.dart';
import '../../../../core/utils/member_qr_service.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/gym_member_model.dart';
import '../../data/models/gym_tenant_model.dart';

/// Full-screen high-tech QR Scanner for Member Check-Ins on Android and iOS.
///
/// Features:
/// - Camera viewfinder with neon laser line and corner brackets
/// - Privacy compliance: only validates within the app
/// - Real-time lookup against loaded facility members
/// - Detailed Verification result: Success card or Expired/Error alert
/// - Manual ID entry fallback for low-light or camera issues
class QrCheckInScannerScreen extends StatefulWidget {
  final AuthController authController;
  final GymTenantModel? tenant;
  final Color primaryColor;

  const QrCheckInScannerScreen({
    super.key,
    required this.authController,
    this.tenant,
    this.primaryColor = AppColors.primary,
  });

  @override
  State<QrCheckInScannerScreen> createState() => _QrCheckInScannerScreenState();
}

class _QrCheckInScannerScreenState extends State<QrCheckInScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  bool _isProcessing = false;
  bool _torchEnabled = false;
  final TextEditingController _manualIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    _manualIdCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue != null && rawValue.isNotEmpty) {
      _processScannedCode(rawValue);
    }
  }

  Future<void> _processScannedCode(String rawCode) async {
    setState(() => _isProcessing = true);

    final payload = MemberQrService.parsePayload(rawCode);
    final memberId = payload?['memberId'] ?? rawCode.trim();

    // 1. Locate member from memory
    GymMemberModel? member = widget.authController.members.where(
      (m) =>
          m.id.toLowerCase() == memberId.toLowerCase() ||
          m.phone.replaceAll(RegExp(r'\D'), '') ==
              memberId.replaceAll(RegExp(r'\D'), ''),
    ).firstOrNull;

    if (!mounted) return;

    if (member == null) {
      // Unrecognized member
      _showResultSheet(
        isSuccess: false,
        title: 'Unrecognized Member QR',
        subtitle:
            'This QR code does not belong to any enrolled member in this facility.',
        detailsWidget: _buildErrorBadge('SCANNED ID: $memberId'),
      );
      return;
    }

    // Check expiry
    final now = DateTime.now();
    final isExpired =
        !member.isLifetimeFree && member.expiryDate.isBefore(now);
    final isInactive = !member.isActive;

    if (isExpired || isInactive) {
      final reason = isExpired
          ? 'Membership Expired on ${member.formattedExpiry}'
          : 'Membership is currently marked as Inactive/Suspended';

      _showResultSheet(
        isSuccess: false,
        title: isExpired ? 'Membership Expired' : 'Membership Inactive',
        subtitle: reason,
        member: member,
        detailsWidget: _buildExpiredBadge(member, reason),
      );
      return;
    }

    // Success: Record check-in attendance
    final tenantId = member.tenantId ??
        widget.tenant?.id ??
        widget.authController.currentGymTenant?.id ??
        widget.authController.currentUser?.tenantId ??
        'default_tenant';

    await widget.authController.recordMemberCheckIn(
      tenantId: tenantId,
      memberId: member.id,
      memberName: member.fullName,
      planName: member.membershipPlan,
      method: 'QR Pass',
    );

    if (!mounted) return;

    _showResultSheet(
      isSuccess: true,
      title: 'Check-In Approved',
      subtitle: 'Attendance successfully logged for ${member.fullName}.',
      member: member,
    );
  }

  void _showResultSheet({
    required bool isSuccess,
    required String title,
    required String subtitle,
    GymMemberModel? member,
    Widget? detailsWidget,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final statusColor = isSuccess ? AppColors.success : AppColors.error;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull indicator
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Status Icon Badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isSuccess
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isSuccess ? Colors.white70 : AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // Member Card Details
              if (member != null && member.id.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSuccess
                          ? widget.primaryColor.withValues(alpha: 0.35)
                          : AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Photo
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.primaryColor.withValues(alpha: 0.2),
                          border: Border.all(
                            color: widget.primaryColor.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: ImageOptimizer.buildImageWidget(
                            member.photoUrl,
                            fit: BoxFit.cover,
                            primaryColor: widget.primaryColor,
                            placeholder: Center(
                              child: Text(
                                member.firstName.isNotEmpty
                                    ? member.firstName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: widget.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.fullName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${member.id.toUpperCase()}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: widget.primaryColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    member.membershipPlan.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: widget.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (member.batchName != null &&
                                    member.batchName!.isNotEmpty)
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF334155),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        member.batchName!,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (detailsWidget != null) detailsWidget,

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context, true); // Return to dashboard
                      },
                      child: const Text('Close Scanner'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = false);
                      },
                      child: Text(
                        isSuccess ? 'Scan Next' : 'Try Again',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  Widget _buildExpiredBadge(GymMemberModel member, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBadge(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Manual Member Check-In',
          style: GoogleFonts.poppins(
              fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Member ID or registered phone number:',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualIdCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E293B),
                hintText: 'e.g. mem_123 or 9876543210',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.person_search_rounded,
                    color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = _manualIdCtrl.text.trim();
              Navigator.pop(dlgCtx);
              if (text.isNotEmpty) {
                _processScannedCode(text);
                _manualIdCtrl.clear();
              }
            },
            child: const Text('Verify & Check In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Mobile Camera Scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded,
                          color: AppColors.error, size: 54),
                      const SizedBox(height: 14),
                      Text(
                        'Camera Unavailable',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Could not access the camera. You can still check in members manually by ID or phone.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: Colors.white70),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _showManualEntryDialog,
                        icon: const Icon(Icons.keyboard_alt_rounded),
                        label: const Text('Manual Entry'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. High-Tech Viewfinder Overlay
          SafeArea(
            child: Column(
              children: [
                // Top Action Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Scan Member Pass',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            const Shadow(color: Colors.black, blurRadius: 8),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                              foregroundColor: _torchEnabled
                                  ? widget.primaryColor
                                  : Colors.white,
                            ),
                            icon: Icon(_torchEnabled
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded),
                            onPressed: () {
                              _scannerController.toggleTorch();
                              setState(() => _torchEnabled = !_torchEnabled);
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.flip_camera_ios_rounded),
                            onPressed: () =>
                                _scannerController.switchCamera(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Center Reticle with scanning laser animation
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: widget.primaryColor.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Animated Scanning Laser Line
                        AnimatedBuilder(
                          animation: _scanAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: 260 * _scanAnimation.value,
                              left: 8,
                              right: 8,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      widget.primaryColor
                                          .withValues(alpha: 0.1),
                                      widget.primaryColor,
                                      widget.primaryColor
                                          .withValues(alpha: 0.1),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.primaryColor,
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Corner Reticles
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _buildCorner(isTop: true, isLeft: true),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _buildCorner(isTop: true, isLeft: false),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: _buildCorner(isTop: false, isLeft: true),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: _buildCorner(isTop: false, isLeft: false),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Manual Entry Trigger & Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Align the QR code on the member\'s I-Card within the frame',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: widget.primaryColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        onPressed: _showManualEntryDialog,
                        icon: const Icon(Icons.dialpad_rounded, size: 18),
                        label: const Text('Enter ID / Phone Manually'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? BorderSide(color: widget.primaryColor, width: 4)
              : BorderSide.none,
          bottom: !isTop
              ? BorderSide(color: widget.primaryColor, width: 4)
              : BorderSide.none,
          left: isLeft
              ? BorderSide(color: widget.primaryColor, width: 4)
              : BorderSide.none,
          right: !isLeft
              ? BorderSide(color: widget.primaryColor, width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }
}
