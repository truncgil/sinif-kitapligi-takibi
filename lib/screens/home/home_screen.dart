import 'package:flutter/material.dart';
import '../student/student_screen.dart';
import '../book/book_screen.dart';
import '../borrow/borrow_screen.dart';
import '../history/history_screen.dart';
import '../class_room/class_room_screen.dart';

/// Ana ekran
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const BorrowScreen(),
    const StudentScreen(),
    const BookScreen(),
    const ClassRoomScreen(),
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Ödünç Ver/Al',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Öğrenciler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Kitaplar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Sınıflar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Geçmiş',
          ),
        ],
      ),
    );
  }
}
