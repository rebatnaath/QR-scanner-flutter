import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'scan_screen.dart';
import 'create_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ScanScreen(),
    const CreateScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/svgs/scan.svg',
              colorFilter: ColorFilter.mode(
                _selectedIndex == 0 ? Colors.blue : Colors.grey,
                BlendMode.srcIn,
              ),
            ),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/svgs/create.svg',
              colorFilter: ColorFilter.mode(
                _selectedIndex == 1 ? Colors.blue : Colors.grey,
                BlendMode.srcIn,
              ),
            ),
            label: 'Create',
          ),
        ],
      ),
    );
  }
}
