/// Centralized string constants for GCRM One application.
class AppStrings {
  AppStrings._();

  // Branding
  static const String appName = 'GCRM ONE';
  static const String appNamePrefix = 'GCRM ';
  static const String appNameSuffix = 'ONE';
  static const String tagline = 'All Your Gym Operations, Unified';
  static const String appDescription =
      'The modern multi-vendor operating system for gym chains, independent fitness clubs, trainers, and members.';

  // Super Admin Portal
  static const String superAdminPortal = 'Super Admin Portal';
  static const String superAdminSubtitle =
      'Platform governance, tenant management, subscription tiers, and global system telemetry.';
  static const String superAdminBadge = 'SUPER ADMIN';

  // Multi-Vendor Roles
  static const String roleSuperAdmin = 'Super Admin';
  static const String roleGymOwner = 'Gym Owner / Vendor';
  static const String roleTrainer = 'Trainer / Staff';
  static const String roleMember = 'Gym Member';

  // Auth Screen Titles & Descriptions
  static const String welcomeBack = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to access your gym workspace';
  static const String createVendorAccount = 'Register New Gym Chain';
  static const String vendorRegisterSubtitle =
      'Onboard your fitness facility to GCRM One in 3 simple steps';
  static const String createMemberAccount = 'Join Your Gym';
  static const String memberRegisterSubtitle =
      'Enter your details & gym code to access your membership pass';
  static const String forgotPasswordTitle = 'Reset Password';
  static const String forgotPasswordSubtitle =
      'Enter your registered email to receive a 6-digit verification code';
  static const String otpTitle = 'Verify Security Code';
  static const String otpSubtitle = 'We sent a 6-digit verification code to';
  static const String resetPasswordTitle = 'Create New Password';
  static const String resetPasswordSubtitle =
      'Ensure your new password contains at least 8 characters, numbers, and symbols';

  // Form Fields & Hints
  static const String email = 'Email Address';
  static const String emailHint = 'e.g. alex@gcrmone.com';
  static const String password = 'Password';
  static const String passwordHint = '••••••••••••';
  static const String confirmPassword = 'Confirm Password';
  static const String confirmPasswordHint = 'Re-enter your password';
  static const String fullName = 'Full Name';
  static const String fullNameHint = 'e.g. Marcus Vance';
  static const String phoneNumber = 'Phone Number';
  static const String phoneNumberHint = '+91 98765 43210';
  static const String gymName = 'Gym Name';
  static const String gymNameHint = 'e.g. IronPulse Fitness Club';
  static const String gymCode = 'Gym Branch / Invite Code';
  static const String gymCodeHint = 'e.g. IRON-NY-01';
  static const String tradeLicense = 'Business / Trade License No.';
  static const String tradeLicenseHint = 'e.g. BLN-994821-NY';
  static const String gymAddress = 'Primary Branch Address';
  static const String gymAddressHint = '742 Evergreen Terrace, Suite 400';

  // Action Buttons
  static const String signIn = 'Sign In';
  static const String signUp = 'Create Account';
  static const String superAdminSignIn = 'Access Super Admin Dashboard';
  static const String continueText = 'Continue';
  static const String back = 'Back';
  static const String verifyOtp = 'Verify Code';
  static const String updatePassword = 'Set New Password';
  static const String resendCode = 'Resend Code';
  static const String switchPortal = 'Switch Portal';
  static const String useDemoAccount = 'Quick Demo Logins';

  // Messages & Errors
  static const String loginSuccess = 'Authentication successful! Redirecting...';
  static const String invalidCredentials = 'Invalid email or password. Please try again.';
  static const String emailRequired = 'Email address is required.';
  static const String invalidEmail = 'Please enter a valid email address.';
  static const String passwordRequired = 'Password is required.';
  static const String passwordTooShort = 'Password must be at least 8 characters.';
  static const String passwordsDoNotMatch = 'Passwords do not match.';
  static const String fieldRequired = 'This field is required.';
  static const String gymCodeRequired = 'Please enter a valid Gym Branch Code.';

  // Demo Credentials
  static const String demoSuperAdminEmail = 'superadmin@gcrmone.com';
  static const String demoSuperAdminPass = 'SuperAdmin@GCRM2026';
  static const String demoOwnerEmail = 'owner@metrofitness.com';
  static const String demoOwnerPass = 'Owner@Metro2026';
  static const String demoTrainerEmail = 'trainer@metrofitness.com';
  static const String demoTrainerPass = 'Trainer@Metro2026';
  static const String demoMemberEmail = 'member@metrofitness.com';
  static const String demoMemberPass = 'Member@Metro2026';
}
