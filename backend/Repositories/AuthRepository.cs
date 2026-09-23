using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Common;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class AuthRepository : IAuthRepository
    {
        private readonly string _connectionString;

        public AuthRepository(IConfiguration configuration)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
        }

        private SqlConnection CreateConnection() => new SqlConnection(_connectionString);

        public async Task<User?> GetUserByUsernameAsync(string username)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT 
                    UserId, Username, Email, PasswordHash, IsActive, IsAdmin,
                    FailedLoginCount, LockedUntil, LastLoginAt, MfaSecret, MfaEnabled,
                    MustChangePassword, CreatedAt, CreatedBy, RoleId
                FROM Users
                WHERE Username = @Username OR Email = @Username;";
            return await connection.QueryFirstOrDefaultAsync<User>(sql, new { Username = username });
        }

        public async Task<User?> GetUserByIdAsync(int userId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT 
                    UserId, Username, Email, PasswordHash, IsActive, IsAdmin,
                    FailedLoginCount, LockedUntil, LastLoginAt, MfaSecret, MfaEnabled,
                    MustChangePassword, CreatedAt, CreatedBy, RoleId
                FROM Users
                WHERE UserId = @UserId;";
            return await connection.QueryFirstOrDefaultAsync<User>(sql, new { UserId = userId });
        }

        public async Task<int> CreateUserAsync(User user)
        {
            using var connection = CreateConnection();
            const string sql = @"
                INSERT INTO Users (
                    Username, Email, PasswordHash, IsActive, IsAdmin,
                    FailedLoginCount, LockedUntil, MfaSecret, MfaEnabled,
                    MustChangePassword, CreatedAt, CreatedBy, RoleId
                )
                OUTPUT INSERTED.UserId
                VALUES (
                    @Username, @Email, @PasswordHash, @IsActive, @IsAdmin,
                    @FailedLoginCount, @LockedUntil, @MfaSecret, @MfaEnabled,
                    @MustChangePassword, @CreatedAt, @CreatedBy, @RoleId
                );";
            return await connection.ExecuteScalarAsync<int>(sql, user);
        }

        public async Task<bool> UpdateUserAsync(User user)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE Users
                SET 
                    Email = @Email,
                    IsActive = @IsActive,
                    IsAdmin = @IsAdmin,
                    RoleId = @RoleId,
                    MustChangePassword = @MustChangePassword
                WHERE UserId = @UserId;";
            var rows = await connection.ExecuteAsync(sql, user);
            return rows > 0;
        }

        public async Task<bool> UpdateLoginSuccessAsync(int userId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE Users
                SET 
                    FailedLoginCount = 0,
                    LockedUntil = NULL,
                    LastLoginAt = GETDATE()
                WHERE UserId = @UserId;";
            var rows = await connection.ExecuteAsync(sql, new { UserId = userId });
            return rows > 0;
        }

        public async Task<bool> RecordFailedLoginAsync(int userId, int failedCount, DateTime? lockedUntil)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE Users
                SET 
                    FailedLoginCount = @FailedCount,
                    LockedUntil = @LockedUntil
                WHERE UserId = @UserId;";
            var rows = await connection.ExecuteAsync(sql, new { 
                UserId = userId, 
                FailedCount = failedCount, 
                LockedUntil = lockedUntil 
            });
            return rows > 0;
        }

        public async Task<bool> UpdatePasswordAsync(int userId, string passwordHash)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE Users
                SET 
                    PasswordHash = @PasswordHash,
                    MustChangePassword = 0,
                    FailedLoginCount = 0,
                    LockedUntil = NULL
                WHERE UserId = @UserId;";
            var rows = await connection.ExecuteAsync(sql, new { 
                UserId = userId, 
                PasswordHash = passwordHash 
            });
            return rows > 0;
        }

        public async Task<bool> SetMfaSecretAsync(int userId, string? secret, bool enabled)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE Users
                SET 
                    MfaSecret = @Secret,
                    MfaEnabled = @Enabled
                WHERE UserId = @UserId;";
            var rows = await connection.ExecuteAsync(sql, new { 
                UserId = userId, 
                Secret = secret, 
                Enabled = enabled 
            });
            return rows > 0;
        }

        public async Task<int> CreateRefreshTokenAsync(RefreshToken token)
        {
            using var connection = CreateConnection();
            const string sql = @"
                INSERT INTO RefreshTokens (
                    UserId, TokenHash, DeviceInfo, IpAddress, IssuedAt, ExpiresAt, RevokedAt, ReplacedByTokenId
                )
                OUTPUT INSERTED.TokenId
                VALUES (
                    @UserId, @TokenHash, @DeviceInfo, @IpAddress, @IssuedAt, @ExpiresAt, @RevokedAt, @ReplacedByTokenId
                );";
            return await connection.ExecuteScalarAsync<int>(sql, token);
        }

        public async Task<RefreshToken?> GetRefreshTokenByHashAsync(string tokenHash)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT 
                    TokenId, UserId, TokenHash, DeviceInfo, IpAddress,
                    IssuedAt, ExpiresAt, RevokedAt, ReplacedByTokenId
                FROM RefreshTokens
                WHERE TokenHash = @TokenHash;";
            return await connection.QueryFirstOrDefaultAsync<RefreshToken>(sql, new { TokenHash = tokenHash });
        }

        public async Task<bool> RevokeRefreshTokenAsync(int tokenId, int? replacedByTokenId = null)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE RefreshTokens
                SET 
                    RevokedAt = GETDATE(),
                    ReplacedByTokenId = @ReplacedByTokenId
                WHERE TokenId = @TokenId AND RevokedAt IS NULL;";
            var rows = await connection.ExecuteAsync(sql, new { 
                TokenId = tokenId, 
                ReplacedByTokenId = replacedByTokenId 
            });
            return rows > 0;
        }

        public async Task<int> RevokeTokenFamilyAsync(int userId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE RefreshTokens
                SET RevokedAt = GETDATE()
                WHERE UserId = @UserId AND RevokedAt IS NULL;";
            return await connection.ExecuteAsync(sql, new { UserId = userId });
        }

        public async Task<IEnumerable<RefreshToken>> GetActiveTokensByUserIdAsync(int userId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT 
                    TokenId, UserId, TokenHash, DeviceInfo, IpAddress,
                    IssuedAt, ExpiresAt, RevokedAt, ReplacedByTokenId
                FROM RefreshTokens
                WHERE UserId = @UserId AND RevokedAt IS NULL AND ExpiresAt > GETDATE()
                ORDER BY IssuedAt DESC;";
            return await connection.QueryAsync<RefreshToken>(sql, new { UserId = userId });
        }

        public async Task<bool> RevokeSessionAsync(int tokenId, int userId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE RefreshTokens
                SET RevokedAt = GETDATE()
                WHERE TokenId = @TokenId AND UserId = @UserId AND RevokedAt IS NULL;";
            var rows = await connection.ExecuteAsync(sql, new { TokenId = tokenId, UserId = userId });
            return rows > 0;
        }

        public async Task<int> RevokeAllSessionsAsync(int userId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE RefreshTokens
                SET RevokedAt = GETDATE()
                WHERE UserId = @UserId AND RevokedAt IS NULL;";
            return await connection.ExecuteAsync(sql, new { UserId = userId });
        }

        public async Task<int> WriteAuditLogAsync(AuthAuditLog log)
        {
            using var connection = CreateConnection();
            const string sql = @"
                INSERT INTO AuthAuditLog (
                    UserId, EventType, IpAddress, DeviceInfo, Timestamp, Success, Detail
                )
                OUTPUT INSERTED.LogId
                VALUES (
                    @UserId, @EventType, @IpAddress, @DeviceInfo, @Timestamp, @Success, @Detail
                );";
            return await connection.ExecuteScalarAsync<int>(sql, log);
        }
    }
}
