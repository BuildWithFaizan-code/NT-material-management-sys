using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Common;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class UserManagementRepository : IUserManagementRepository
    {
        private readonly string _connectionString;

        public UserManagementRepository(IConfiguration configuration)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
        }

        private SqlConnection CreateConnection() => new(_connectionString);

        public async Task<IEnumerable<UserManagementItemDto>> GetAllUsersAsync()
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT 
                    u.UserId, 
                    u.Username, 
                    u.Email, 
                    u.IsActive, 
                    u.IsAdmin, 
                    u.RoleId, 
                    r.RoleName, 
                    u.LastLoginAt, 
                    u.CreatedAt
                FROM Users u
                LEFT JOIN Roles r ON r.RoleId = u.RoleId
                ORDER BY u.UserId ASC;";
            return await connection.QueryAsync<UserManagementItemDto>(sql);
        }

        public async Task<UserManagementItemDto?> GetUserByIdAsync(int userId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT 
                    u.UserId, 
                    u.Username, 
                    u.Email, 
                    u.IsActive, 
                    u.IsAdmin, 
                    u.RoleId, 
                    r.RoleName, 
                    u.LastLoginAt, 
                    u.CreatedAt
                FROM Users u
                LEFT JOIN Roles r ON r.RoleId = u.RoleId
                WHERE u.UserId = @UserId;";
            return await connection.QueryFirstOrDefaultAsync<UserManagementItemDto>(sql, new { UserId = userId });
        }

        public async Task<bool> UpdateUserAsync(int userId, string email, int? roleId, bool isActive)
        {
            using var connection = CreateConnection();
            const string sql = @"
                UPDATE Users
                SET Email = @Email,
                    RoleId = @RoleId,
                    IsActive = @IsActive
                WHERE UserId = @UserId;";
            var rows = await connection.ExecuteAsync(sql, new { 
                UserId = userId, 
                Email = email.Trim(), 
                RoleId = roleId, 
                IsActive = isActive 
            });
            return rows > 0;
        }

        public async Task<bool> SetUserActiveStatusAsync(int userId, bool isActive)
        {
            using var connection = CreateConnection();
            const string sql = "UPDATE Users SET IsActive = @IsActive WHERE UserId = @UserId;";
            var rows = await connection.ExecuteAsync(sql, new { UserId = userId, IsActive = isActive });
            return rows > 0;
        }

        public async Task<bool> DeleteUserAsync(int userId)
        {
            using var connection = CreateConnection();
            const string sql = "DELETE FROM Users WHERE UserId = @UserId;";
            var rows = await connection.ExecuteAsync(sql, new { UserId = userId });
            return rows > 0;
        }
    }
}
