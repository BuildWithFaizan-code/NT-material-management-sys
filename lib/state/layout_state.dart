import 'package:flutter/material.dart';
import '../design/app_dimensions.dart';

enum ScreenSize { small, large }

class LayoutState extends ChangeNotifier {
  ScreenSize _screenSize = ScreenSize.large;
  int _currentPageIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ScreenSize get screenSize => _screenSize;
  int get currentPageIndex => _currentPageIndex;
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
      notifyListeners();
    }
  }

  void setPage(int index) {
    if (index != _currentPageIndex) {
      _currentPageIndex = index;
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
