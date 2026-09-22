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
-- Seed Initial Admin User (Default Password: "ChangeMe123!", MustChangePassword = 1)
-- Note: Password hash below was generated using BCrypt work factor 11 for "ChangeMe123!"
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM Users WHERE Username = 'admin')
BEGIN
    INSERT INTO Users (Username, Email, PasswordHash, IsActive, IsAdmin, FailedLoginCount, MustChangePassword, CreatedAt)
    VALUES (
        'admin',
        'admin@newtechmms.com',
        '$2a$11$uqWe7AOmgVwnNc7vW1qmhOJfpeaxHvMdvBWGwbIOBkBpGza2K3p5m', -- BCrypt hash for 'ChangeMe123!'
        1,
        1,
        0,
        1,
        GETDATE()
    );
END
GO
