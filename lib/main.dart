import 'package:flutter/material.dart';
import 'controllers/expense_controller.dart';
import 'services/notification_service.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = ExpenseController();
  await controller.init();

  // Initialize notifications and reschedule if enabled
  final notifService = NotificationService();
  await notifService.init();
  await notifService.rescheduleIfNeeded();

  runApp(MyApp(controller: controller));
}

class MyApp extends StatelessWidget {
  final ExpenseController controller;

  const MyApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ledgr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(controller: controller),
    );
  }
}
