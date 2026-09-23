-- ============================================================================
-- NT Material Management System (NT-MMS)
-- Script: 002_CreateRolePermissionTables.sql
-- Description: Creates Role & Permission tables (Roles, Modules, Actions,
--              RolePermissions, PermissionAuditLog), adds RoleId to Users,
--              and seeds standard Actions and the 17 Master Modules.
-- ============================================================================

-- 1. Roles Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Roles')
BEGIN
    CREATE TABLE Roles (
        RoleId INT IDENTITY(1,1) PRIMARY KEY,
        RoleName NVARCHAR(100) NOT NULL,
        CreatedBy INT NULL,
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName)
    );
END
GO

-- 2. Modules Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Modules')
BEGIN
    CREATE TABLE Modules (
        ModuleId INT IDENTITY(1,1) PRIMARY KEY,
        ModuleName NVARCHAR(100) NOT NULL,
        ModuleGroup NVARCHAR(50) NOT NULL,
        ControllerName NVARCHAR(100) NOT NULL
    );

    CREATE UNIQUE NONCLUSTERED INDEX IX_Modules_ControllerName ON Modules(ControllerName);
END
GO

-- 3. Actions Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Actions')
BEGIN
    CREATE TABLE Actions (
        ActionId INT IDENTITY(1,1) PRIMARY KEY,
        ActionName NVARCHAR(50) NOT NULL,
        HttpVerb NVARCHAR(10) NOT NULL
    );
END
GO

-- 4. RolePermissions Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RolePermissions')
BEGIN
    CREATE TABLE RolePermissions (
        RoleId INT NOT NULL,
        ModuleId INT NOT NULL,
        ActionId INT NOT NULL,
        CONSTRAINT PK_RolePermissions PRIMARY KEY (RoleId, ModuleId, ActionId),
        CONSTRAINT FK_RolePermissions_Roles FOREIGN KEY (RoleId) REFERENCES Roles(RoleId) ON DELETE CASCADE,
        CONSTRAINT FK_RolePermissions_Modules FOREIGN KEY (ModuleId) REFERENCES Modules(ModuleId),
        CONSTRAINT FK_RolePermissions_Actions FOREIGN KEY (ActionId) REFERENCES Actions(ActionId)
    );

    CREATE NONCLUSTERED INDEX IX_RolePermissions_RoleId ON RolePermissions(RoleId);
END
GO

-- 5. PermissionAuditLog Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PermissionAuditLog')
BEGIN
    CREATE TABLE PermissionAuditLog (
        LogId INT IDENTITY(1,1) PRIMARY KEY,
        ChangedBy INT NOT NULL,
        RoleId INT NOT NULL,
        ModuleId INT NOT NULL,
        ActionId INT NOT NULL,
        Change NVARCHAR(20) NOT NULL, -- 'Granted' / 'Revoked'
        Timestamp DATETIME NOT NULL DEFAULT GETDATE()
    );

    CREATE NONCLUSTERED INDEX IX_PermissionAuditLog_RoleId ON PermissionAuditLog(RoleId);
    CREATE NONCLUSTERED INDEX IX_PermissionAuditLog_Timestamp ON PermissionAuditLog(Timestamp DESC);
END
GO

-- 6. Add RoleId to Users Table (if not exists)
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('Users') AND name = 'RoleId'
)
BEGIN
    ALTER TABLE Users ADD RoleId INT NULL;
    ALTER TABLE Users ADD CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES Roles(RoleId);
    CREATE NONCLUSTERED INDEX IX_Users_RoleId ON Users(RoleId);
END
GO

-- ============================================================================
-- Seed Data: Actions (Exactly 4 rows)
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM Actions WHERE ActionName = 'View' AND HttpVerb = 'GET')
    INSERT INTO Actions (ActionName, HttpVerb) VALUES ('View', 'GET');

IF NOT EXISTS (SELECT 1 FROM Actions WHERE ActionName = 'Add' AND HttpVerb = 'POST')
    INSERT INTO Actions (ActionName, HttpVerb) VALUES ('Add', 'POST');

IF NOT EXISTS (SELECT 1 FROM Actions WHERE ActionName = 'Update' AND HttpVerb = 'PUT')
    INSERT INTO Actions (ActionName, HttpVerb) VALUES ('Update', 'PUT');

IF NOT EXISTS (SELECT 1 FROM Actions WHERE ActionName = 'Delete' AND HttpVerb = 'DELETE')
    INSERT INTO Actions (ActionName, HttpVerb) VALUES ('Delete', 'DELETE');
GO

-- ============================================================================
-- Seed Data: Modules (Exactly 17 Master Modules, verified against Controller classes)
-- ============================================================================
MERGE INTO Modules AS target
USING (VALUES
    ('Project Master', 'Master', 'ProjectMasterController'),
    ('Location Master', 'Master', 'LocationMasterController'),
    ('Store Master', 'Master', 'StoreMasterController'),
    ('Operator Master', 'Master', 'OperatorMasterController'),
    ('Operation Master', 'Master', 'OperationMasterController'),
    ('Department Master', 'Master', 'DepartmentMasterController'),
    ('Sub-Department Master', 'Master', 'SubDepartmentMasterController'),
    ('Non-Stockable Item', 'Master', 'NonStockableItemController'),
    ('Head Master', 'Master', 'HeadMasterController'),
    ('Book Master', 'Master', 'BookMasterController'),
    ('Fabric Size Master', 'Master', 'FabricSizeMasterController'),
    ('Makers Master', 'Master', 'MakersMasterController'),
    ('Capital / Consumable', 'Master', 'CapitalConsumableMasterController'),
    ('Grade Master', 'Master', 'GradeMasterController'),
    ('Main Group Master', 'Master', 'MainGroupMasterController'),
    ('Group Master', 'Master', 'GroupMasterController'),
    ('Group Master Definition', 'Master', 'GroupMasterDefinitionController')
) AS source (ModuleName, ModuleGroup, ControllerName)
ON target.ControllerName = source.ControllerName
WHEN MATCHED THEN
    UPDATE SET target.ModuleName = source.ModuleName, target.ModuleGroup = source.ModuleGroup
WHEN NOT MATCHED THEN
    INSERT (ModuleName, ModuleGroup, ControllerName)
    VALUES (source.ModuleName, source.ModuleGroup, source.ControllerName);
GO
