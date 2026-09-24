import 'package:flutter_test/flutter_test.dart';
import 'package:newtechmms/layout/widgets/master_nav_item.dart';
import 'package:newtechmms/services/role_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Master Module & Permission Logic Tests', () {
    test('masterSubSections contains exactly 18 Master modules including Charges Master', () {
      expect(masterSubSections.length, 18);
      final titles = masterSubSections.map((s) => s.title).toList();
      expect(titles.contains('Charges Master'), isTrue);
      expect(titles.contains('Project Master'), isTrue);
      expect(titles.contains('Location Master'), isTrue);
      expect(titles.contains('Store Master'), isTrue);
    });

    test('MyPermissions.canViewModule grants all modules for Admin', () {
      final adminPerms = MyPermissions(
        isAdmin: true,
        roleId: null,
        permissions: [],
      );

      for (final sub in masterSubSections) {
        expect(adminPerms.canViewModule(sub.title), isTrue);
      }
    });

    test('MyPermissions.canViewModule filters modules strictly for Non-Admin', () {
      final subUserPerms = MyPermissions(
        isAdmin: false,
        roleId: 4,
        permissions: [
          UserPermissionItem(
            moduleId: 1,
            actionId: 1,
            moduleName: 'Project Master',
            actionName: 'View',
            controllerName: 'ProjectMasterController',
          ),
          UserPermissionItem(
            moduleId: 2,
            actionId: 1,
            moduleName: 'Location Master',
            actionName: 'View',
            controllerName: 'LocationMasterController',
          ),
          UserPermissionItem(
            moduleId: 3,
            actionId: 1,
            moduleName: 'Store Master',
            actionName: 'View',
            controllerName: 'StoreMasterController',
          ),
          UserPermissionItem(
            moduleId: 18,
            actionId: 2, // Add only (No View!)
            moduleName: 'Charges Master',
            actionName: 'Add',
            controllerName: 'ChargesMasterController',
          ),
        ],
      );

      // Permitted with View
      expect(subUserPerms.canViewModule('Project Master'), isTrue);
      expect(subUserPerms.canViewModule('Location Master'), isTrue);
      expect(subUserPerms.canViewModule('Store Master'), isTrue);

      // Not granted View
      expect(subUserPerms.canViewModule('Operator Master'), isFalse);
      expect(subUserPerms.canViewModule('Charges Master'), isFalse);
      expect(subUserPerms.canViewModule('Book Master'), isFalse);
    });
  });

  group('MasterNavItem UI Filtering Tests', () {
    testWidgets('Non-admin user sees ONLY the 3 permitted modules in MasterNavItem', (tester) async {
      // Mock sub-user permissions: Project, Location, Store only
      final subUserPerms = MyPermissions(
        isAdmin: false,
        roleId: 4,
        permissions: [
          UserPermissionItem(
            moduleId: 1,
            actionId: 1,
            moduleName: 'Project Master',
            actionName: 'View',
            controllerName: 'ProjectMasterController',
          ),
          UserPermissionItem(
            moduleId: 2,
            actionId: 1,
            moduleName: 'Location Master',
            actionName: 'View',
            controllerName: 'LocationMasterController',
          ),
          UserPermissionItem(
            moduleId: 3,
            actionId: 1,
            moduleName: 'Store Master',
            actionName: 'View',
            controllerName: 'StoreMasterController',
          ),
        ],
      );

      // Test filtering logic directly:
      final visible = masterSubSections.where((s) => subUserPerms.canViewModule(s.title)).toList();
      expect(visible.length, 3);
      expect(visible.map((s) => s.title), containsAll(['Project Master', 'Location Master', 'Store Master']));
      expect(visible.map((s) => s.title), isNot(contains('Charges Master')));
      expect(visible.map((s) => s.title), isNot(contains('Operator Master')));
    });
  });
}
