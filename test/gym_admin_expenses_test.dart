import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/gym_admin_dashboard_screen.dart';

void main() {
  group('GymExpenseModel Unit Tests', () {
    test('serializes and deserializes accurately with all category helpers', () {
      final date = DateTime(2026, 8, 31, 14, 30);
      final expense = GymExpenseRecord(
        id: 'exp_101',
        tenantId: 'tenant_metro_01',
        title: 'Treadmill Inverter Replacement',
        category: 'Equipment & Upkeep',
        amount: 8500.0,
        date: date,
        paymentMethod: 'UPI / Online',
        notes: 'Invoice #INV-2026-881',
      );

      expect(expense.id, 'exp_101');
      expect(expense.formattedAmount, '₹8500');
      expect(expense.formattedDate, '31 Aug 2026');
      expect(expense.categoryEnum, GymExpenseCategory.equipmentUpkeep);
      expect(expense.color, isNotNull);
      expect(expense.icon, Icons.fitness_center_rounded);

      final json = expense.toJson();
      expect(json['title'], 'Treadmill Inverter Replacement');
      expect(json['amount'], 8500.0);
      expect(json['category'], 'Equipment & Upkeep');
      expect(json['paymentMethod'], 'UPI / Online');

      final restored = GymExpenseRecord.fromJson(json);
      expect(restored.id, 'exp_101');
      expect(restored.title, 'Treadmill Inverter Replacement');
      expect(restored.amount, 8500.0);
      expect(restored.category, 'Equipment & Upkeep');
      expect(restored.notes, 'Invoice #INV-2026-881');
    });

    test('handles decimal formattedAmount accurately', () {
      final expense = GymExpenseRecord(
        id: 'exp_102',
        title: 'Sanitization Supplies',
        category: 'Marketing & Ops',
        amount: 450.50,
        date: DateTime.now(),
      );

      expect(expense.formattedAmount, '₹450.50');
    });
  });

  group('Gym Admin Dashboard Expenses Tab Widget Tests', () {
    late AuthController authController;
    late MockAuthService mockAuthService;

    setUp(() async {
      mockAuthService = MockAuthService();
      mockAuthService.resetForTesting();
      authController = AuthController(authRepository: mockAuthService);
      await authController.login(email: 'metro@gym.com', password: 'Password@123');
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: GymAdminDashboardScreen(authController: authController),
      );
    }

    testWidgets('Expenses tab is visible in tab bar and renders empty state initially', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify Expenses tab exists
      expect(find.text('Expenses'), findsOneWidget);

      // Tap Expenses tab
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();

      // Verify Expenses Tab UI elements
      expect(find.text('OPERATIONAL EXPENSES'), findsOneWidget);
      expect(find.text('Total Outflow'), findsOneWidget);
      expect(find.text('This Month'), findsNWidgets(2)); // KPI card + filter chip
      expect(find.text('Entries Logged'), findsOneWidget);
      expect(find.text('No Expenses Logged Yet'), findsOneWidget);
      expect(find.text('Record First Expense'), findsOneWidget);
    });

    testWidgets('Adding an expense via modal saves and renders card in ledger', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Navigate to Expenses tab
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();

      // Tap FAB button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify modal opened
      expect(find.text('Record Operating Expense'), findsOneWidget);

      // Fill in Title
      final titleField = find.widgetWithText(TextFormField, 'e.g. Treadmill Motor Servicing');
      await tester.enterText(titleField, 'AC Servicing & Gas Top-up');

      // Fill in Amount
      final amountField = find.widgetWithText(TextFormField, 'e.g. 4500');
      await tester.enterText(amountField, '3200');

      // Tap "Record Expense" in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Record Expense'));
      await tester.pumpAndSettle();

      // Verify expense card is now rendered in list & all KPI cards dynamically updated
      expect(find.text('AC Servicing & Gas Top-up'), findsOneWidget);
      expect(find.text('₹3200'), findsNWidgets(4)); // Total Outflow + This Month + Top Category + Card Amount
      expect(find.text('1 transactions'), findsOneWidget);
    });

    testWidgets('Overview tab shows dynamic zero-state when no expenses exist and updates on expense record', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // On Overview tab initially
      expect(find.text('EXPENSES & CASH OUTFLOW'), findsOneWidget);
      expect(find.text('No expenses recorded yet'), findsOneWidget);
      expect(find.text('₹0 Logged'), findsOneWidget);
      expect(find.text('No Outflows Logged'), findsOneWidget);

      // Tap "Record Operational Expense" shortcut from Overview Tab
      await tester.tap(find.text('Record Operational Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Record Operating Expense'), findsOneWidget);

      // Fill in Title & Amount
      final titleField = find.widgetWithText(TextFormField, 'e.g. Treadmill Motor Servicing');
      await tester.enterText(titleField, 'Diesel Generator Fuel');

      final amountField = find.widgetWithText(TextFormField, 'e.g. 4500');
      await tester.enterText(amountField, '5000');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Record Expense'));
      await tester.pumpAndSettle();

      // Overview Tab now dynamically shows recorded expense stats
      expect(find.text('1 entries recorded'), findsOneWidget);
      expect(find.text('₹5000'), findsNWidgets(3)); // Header badge + Donut center + Category row item
      expect(find.text('100%'), findsOneWidget); // Dynamic 100% for the single category
    });
  });
}
