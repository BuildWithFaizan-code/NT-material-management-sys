import 'package:flutter/material.dart';
import '../design/app_dimensions.dart';

enum ScreenSize { small, large }

class LayoutState extends ChangeNotifier {
  ScreenSize _screenSize = ScreenSize.large;
  int _currentPageIndex = 0;
  String _selectedMasterSubItem = '';
  bool _isNavbarOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ScreenSize get screenSize => _screenSize;
  int get currentPageIndex => _currentPageIndex;
  String get selectedMasterSubItem => _selectedMasterSubItem;
  bool get isNavbarOpen => _isNavbarOpen;
  GlobalKey<ScaffoldState> get scaffoldKey => _scaffoldKey;

  bool get isLarge => _screenSize == ScreenSize.large;

  ScreenSize resolveScreenSize(double width) {
    return width > AppDimensions.mobileBreakpoint
        ? ScreenSize.large
        : ScreenSize.small;
  }

  void onResize(double width) {
    final newSize = resolveScreenSize(width);
    if (newSize != _screenSize) {
      _screenSize = newSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void setPage(int index) {
    if (index == 1 && _selectedMasterSubItem.isEmpty) {
      _selectedMasterSubItem = 'Project Master';
    }
    if (index != _currentPageIndex) {
      _currentPageIndex = index;
      notifyListeners();
    }
  }

  void setMasterSubItem(String subItemTitle) {
    _selectedMasterSubItem = subItemTitle;
    _currentPageIndex = 1;
    notifyListeners();
  }

  void toggleNavbar() {
    _isNavbarOpen = !_isNavbarOpen;
    notifyListeners();
  }

  void setNavbarOpen(bool open) {
    if (_isNavbarOpen != open) {
      _isNavbarOpen = open;
      notifyListeners();
    }
  }

  void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void closeDrawer() {
    _scaffoldKey.currentState?.closeDrawer();
  }
}
