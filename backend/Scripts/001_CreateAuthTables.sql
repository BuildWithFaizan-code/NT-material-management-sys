-- ============================================================================
-- NT Material Management System (NT-MMS)
-- Script: 001_CreateAuthTables.sql
-- Description: Creates Core Authentication tables (Users, RefreshTokens, AuthAuditLog)
--              Strictly matching Section 4 of NT-MMS Authentication Core Build Plan.
-- ============================================================================

-- 1. Users Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
BEGIN
    CREATE TABLE Users (
        UserId INT IDENTITY(1,1) PRIMARY KEY,
        Username NVARCHAR(100) NOT NULL,
        Email NVARCHAR(255) NOT NULL,
        PasswordHash NVARCHAR(255) NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        IsAdmin BIT NOT NULL DEFAULT 0,
        FailedLoginCount INT NOT NULL DEFAULT 0,
        LockedUntil DATETIME NULL,
        LastLoginAt DATETIME NULL,
        MfaSecret NVARCHAR(255) NULL,
        MfaEnabled BIT NOT NULL DEFAULT 0,
        MustChangePassword BIT NOT NULL DEFAULT 0,
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
        CreatedBy INT NULL
    );

    CREATE UNIQUE NONCLUSTERED INDEX UX_Users_Username ON Users(Username);
    CREATE UNIQUE NONCLUSTERED INDEX UX_Users_Email ON Users(Email);
END
GO

-- 2. RefreshTokens Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RefreshTokens')
BEGIN
    CREATE TABLE RefreshTokens (
        TokenId INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NOT NULL,
        TokenHash NVARCHAR(255) NOT NULL,
        DeviceInfo NVARCHAR(255) NULL,
        IpAddress NVARCHAR(45) NULL,
        IssuedAt DATETIME NOT NULL DEFAULT GETDATE(),
        ExpiresAt DATETIME NOT NULL,
        RevokedAt DATETIME NULL,
        ReplacedByTokenId INT NULL,
        CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE
    );

    CREATE NONCLUSTERED INDEX IX_RefreshTokens_TokenHash ON RefreshTokens(TokenHash);
    CREATE NONCLUSTERED INDEX IX_RefreshTokens_UserId ON RefreshTokens(UserId);
    CREATE NONCLUSTERED INDEX IX_RefreshTokens_ReplacedByTokenId ON RefreshTokens(ReplacedByTokenId);
END
GO

-- 3. AuthAuditLog Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuthAuditLog')
BEGIN
    CREATE TABLE AuthAuditLog (
        LogId INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NULL,
        EventType NVARCHAR(50) NOT NULL,
        IpAddress NVARCHAR(45) NULL,
        DeviceInfo NVARCHAR(255) NULL,
        Timestamp DATETIME NOT NULL DEFAULT GETDATE(),
        Success BIT NOT NULL,
        Detail NVARCHAR(500) NULL
    );

    CREATE NONCLUSTERED INDEX IX_AuthAuditLog_UserId ON AuthAuditLog(UserId);
    CREATE NONCLUSTERED INDEX IX_AuthAuditLog_Timestamp ON AuthAuditLog(Timestamp DESC);
END
GO

-- ============================================================================
-- Seed Initial Admin User (LOCKED BY DEFAULT - ZERO PREDICTABLE CREDENTIALS)
-- ============================================================================
-- IMPORTANT SECURITY POLICY:
-- The initial admin account is intentionally inserted with IsActive = 0 and an invalid
-- placeholder hash. It cannot be used to authenticate until explicitly provisioned.
--
-- Provisioning Method 1 (Recommended - CLI):
--   Run the backend provisioning command with your custom secure password:
--   dotnet run --project backend/MMSERP.Api.csproj -- --provision-admin <username> <email> <password>
--   Or set the environment variable INITIAL_ADMIN_PASSWORD before launching the API.
--
-- Provisioning Method 2 (DBA Manual SQL Update):
--   Generate a BCrypt hash with work factor 11 (e.g., using any standard BCrypt generator)
--   and activate the account:
--     UPDATE Users
--     SET PasswordHash = '<your_bcrypt_hash>',
--         IsActive = 1,
--         MustChangePassword = 1
--     WHERE Username = 'admin';
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM Users WHERE Username = 'admin')
BEGIN
    INSERT INTO Users (Username, Email, PasswordHash, IsActive, IsAdmin, FailedLoginCount, MustChangePassword, CreatedAt)
    VALUES (
        'admin',
        'admin@newtechmms.com',
        'LOCKED_PENDING_PROVISIONING',
        0, -- Disabled by default until provisioned via CLI or DBA
        1, -- IsAdmin
        0, -- FailedLoginCount
        1, -- MustChangePassword
        GETDATE()
    );
END
GO
