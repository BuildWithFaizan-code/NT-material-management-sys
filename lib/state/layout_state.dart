import 'package:flutter/material.dart';
import '../design/app_dimensions.dart';
import '../services/auth_service.dart';

enum ScreenSize { small, large }

class LayoutState extends ChangeNotifier {
  ScreenSize _screenSize = ScreenSize.large;
  int _currentPageIndex = 0;
  String _selectedMasterSubItem = '';
  String _selectedTransactionSubItem = '';
  bool _isNavbarOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  LayoutState({bool parseUri = true, Uri? initialUri}) {
    if (parseUri) {
      initFromUri(initialUri);
    }
  }

  ScreenSize get screenSize => _screenSize;
  int get currentPageIndex => _currentPageIndex;
  String get selectedMasterSubItem => _selectedMasterSubItem;
  String get selectedTransactionSubItem => _selectedTransactionSubItem;
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
      final user = AuthService.instance.currentUser;
      final defaultItem = user?.isAdmin == true
          ? 'Project Master'
          : (user?.permittedModules.isNotEmpty == true
              ? user!.permittedModules.first
              : 'Project Master');
      _selectedMasterSubItem = defaultItem;
    }
    if (index == 2 && _selectedTransactionSubItem.isEmpty) {
      _selectedTransactionSubItem = 'Bill of Material (BOM)';
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

  void setTransactionSubItem(String subItemTitle) {
    _selectedTransactionSubItem = subItemTitle;
    _currentPageIndex = 2;
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

  /// Parses initial deep-link or iframe query parameters from URL.
  /// Supports: ?page=..., ?module=..., ?sub=...
  void initFromUri([Uri? customUri]) {
    try {
      final uri = customUri ?? Uri.base;
      final params = uri.queryParameters;
      if (params.isEmpty) return;

      final page = params['page']?.toLowerCase().trim();
      final module = (params['module'] ?? params['sub'] ?? params['item'])
          ?.toLowerCase()
          .trim();

      // Check if direct module shortcut is provided
      if (module != null && module.isNotEmpty) {
        if (_trySetMasterBySlug(module)) return;
        if (_trySetTransactionBySlug(module)) return;
      }

      if (page != null && page.isNotEmpty) {
        switch (page) {
          case 'dashboard':
          case '0':
            setPage(0);
            break;
          case 'master':
          case 'masters':
          case '1':
            if (module != null && _trySetMasterBySlug(module)) {
              // matched and navigated
            } else {
              setPage(1);
            }
            break;
          case 'transaction':
          case 'transactions':
          case '2':
            if (module != null && _trySetTransactionBySlug(module)) {
              // matched and navigated
            } else {
              setPage(2);
            }
            break;
          case 'report':
          case 'reports':
          case '3':
            setPage(3);
            break;
          case 'box':
          case 'boxregister':
          case 'box_register':
          case '4':
            setPage(4);
            break;
          case 'tools':
          case '5':
            setPage(5);
            break;
          case 'live':
          case 'liveupdates':
          case 'live_updates':
          case '6':
            setPage(6);
            break;
          case 'download':
          case 'downloads':
          case '7':
            setPage(7);
            break;
          case 'usermanagement':
          case 'users':
          case '8':
            setPage(8);
            break;
          default:
            // Check if page parameter was a direct module slug (e.g. ?page=location)
            if (_trySetMasterBySlug(page)) return;
            if (_trySetTransactionBySlug(page)) return;
        }
      }
    } catch (_) {
      // Gracefully ignore query parsing failures
    }
  }

  bool _trySetMasterBySlug(String slug) {
    final normalized =
        slug.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    const masterMap = {
      'project': 'Project Master',
      'projectmaster': 'Project Master',
      'location': 'Location Master',
      'locationmaster': 'Location Master',
      'store': 'Store Master',
      'storemaster': 'Store Master',
      'operator': 'Operator Master',
      'operatormaster': 'Operator Master',
      'operation': 'Operation Master',
      'operationmaster': 'Operation Master',
      'department': 'Department Master',
      'departmentmaster': 'Department Master',
      'subdepartment': 'Sub-Department Master',
      'subdepartmentmaster': 'Sub-Department Master',
      'head': 'Head Master',
      'headmaster': 'Head Master',
      'costinghead': 'Head Master',
      'book': 'Book Master',
      'bookmaster': 'Book Master',
      'fabricsize': 'Fabric Size Master',
      'fabricsizemaster': 'Fabric Size Master',
      'maker': 'Makers Master',
      'makers': 'Makers Master',
      'makersmaster': 'Makers Master',
      'capital': 'Capital / Consumable',
      'consumable': 'Capital / Consumable',
      'capitalconsumable': 'Capital / Consumable',
      'capitalconsumablemaster': 'Capital / Consumable',
      'grade': 'Grade Master',
      'grademaster': 'Grade Master',
      'maingroup': 'Main Group Master',
      'maingroupmaster': 'Main Group Master',
      'group': 'Group Master',
      'groupmaster': 'Group Master',
      'groupcategory': 'Group Master',
      'groupdefinition': 'Group Master Definition',
      'groupmasterdefinition': 'Group Master Definition',
      'nonstockable': 'Non-Stockable Item',
      'nonstockableitem': 'Non-Stockable Item',
      'nonstockableitemmaster': 'Non-Stockable Item',
    };

    if (masterMap.containsKey(normalized)) {
      setMasterSubItem(masterMap[normalized]!);
      return true;
    }
    return false;
  }

  bool _trySetTransactionBySlug(String slug) {
    final normalized =
        slug.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    const txMap = {
      'bom': 'Bill of Material (BOM)',
      'billofmaterial': 'Bill of Material (BOM)',
      'productionorder': 'Production Order',
      'bomfollowup': 'BOM Followup',
      'productionorderclose': 'Production Order Close',
      'repackproductionorder': 'Repack Production Order',
      'wipfollowup': 'WIP Followup',
      'estimaterequirements': 'Estimate Requirements',
      'requisition': 'Requisition',
      'requisitionstatus': 'Requisition Status',
      'indent': 'Create Indent',
      'createindent': 'Create Indent',
      'indentapproval': 'Indent Approval',
      'enquiry': 'Enquiry Creation',
      'enquirycreation': 'Enquiry Creation',
      'quotation': 'Quotation Manager',
      'quotationmanager': 'Quotation Manager',
      'salesorder': 'Generate Sales Order',
      'generatesalesorder': 'Generate Sales Order',
      'releasesalesorder': 'Release Sales Order',
      'po': 'Generate Purchase Order',
      'purchaseorder': 'Generate Purchase Order',
      'generatepurchaseorder': 'Generate Purchase Order',
      'releasepurchaseorder': 'Release Purchase Order',
      'poadvance': 'PO Advance Entry',
      'poadvanceentry': 'PO Advance Entry',
      'freightmemo': 'Freight Memo',
      'gateentry': 'Gate Entry Manager',
      'gateentrymanager': 'Gate Entry Manager',
      'materialreceipt': 'Material Receipt',
      'intercompanyinward': 'Inter Company Inward',
      'materialinspection': 'Material Inspection',
      'partypayment': 'Party Payment',
      'stocktransfer': 'Stock Transfer',
      'issuemanager': 'Issue Manager',
      'wipapproval': 'WIP Approval',
      'materialreturn': 'Material Return From/To',
      'inputscreen': 'Input Screen',
      'costofmaintenance': 'Cost of Maintenance',
      'costofmaterial': 'Cost Of Material',
      'palletreturnable': 'Pallet Returnable Entry',
      'gatepass': 'Gate Pass',
      'stockadjustment': 'Stock Adjustment',
      'rollcutting': 'Roll Cutting Entry',
      'jobwork': 'Jobwork Manager',
      'jobworkmanager': 'Jobwork Manager',
      'joborder': 'Job Order',
      'jobworkreceipt': 'Jobwork Receipt',
      'rgp': 'RGP',
      'workorder': 'Create Work Order',
      'createworkorder': 'Create Work Order',
      'workorderapproval': 'Work Order Approval',
      'workordergateentry': 'Work Order Gate Entry',
      'workordergrn': 'Work Order GRN',
      'rgpreceived': 'RGP RECEIVED',
    };

    if (txMap.containsKey(normalized)) {
      setTransactionSubItem(txMap[normalized]!);
      return true;
    }
    return false;
  }
}
