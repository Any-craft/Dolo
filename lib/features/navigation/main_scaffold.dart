import 'package:flutter/material.dart';
import '../home/presentation/screens/home_screen.dart';
import '../groups/presentation/screens/groups_list_screen.dart';
import '../settlement/presentation/screens/spends_screen.dart';
import '../settlement/presentation/screens/profile_screen.dart';
import '../expense/presentation/screens/add_expense_screen.dart';
import '../settlement/presentation/screens/settle_up_sheet.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onAddExpenseTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
        },
        onSettleUpTap: () {
          SettleUpSheet.show(
            context,
            peerId: 'sheeda',
            peerName: 'Sheeda',
          );
        },
        onProfileTap: () {
          setState(() => _currentIndex = 3);
        },
        onSpendsTap: () {
          setState(() => _currentIndex = 2);
        },
      ),
      const GroupsListScreen(),
      const SpendsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_rounded),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_rounded),
            label: 'Spends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}