using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Common;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class RolePermissionRepository : IRolePermissionRepository
    {
        private readonly string _connectionString;

        public RolePermissionRepository(IConfiguration configuration)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
        }

        private SqlConnection CreateConnection() => new(_connectionString);

        public async Task<ModuleItem?> GetModuleByControllerNameAsync(string controllerName)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT ModuleId, ModuleName, ModuleGroup, ControllerName
                FROM Modules
                WHERE ControllerName = @ControllerName;";
            return await connection.QueryFirstOrDefaultAsync<ModuleItem>(sql, new { ControllerName = controllerName });
        }

        public async Task<IEnumerable<ModuleItem>> GetAllModulesAsync()
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT ModuleId, ModuleName, ModuleGroup, ControllerName
                FROM Modules
                ORDER BY ModuleId ASC;";
            return await connection.QueryAsync<ModuleItem>(sql);
        }

        public async Task<ActionItem?> GetActionByHttpVerbAsync(string verb)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT ActionId, ActionName, HttpVerb
                FROM Actions
                WHERE UPPER(HttpVerb) = UPPER(@Verb);";
            return await connection.QueryFirstOrDefaultAsync<ActionItem>(sql, new { Verb = verb });
        }

        public async Task<IEnumerable<ActionItem>> GetAllActionsAsync()
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT ActionId, ActionName, HttpVerb
                FROM Actions
                ORDER BY ActionId ASC;";
            return await connection.QueryAsync<ActionItem>(sql);
        }

        public async Task<HashSet<(int ModuleId, int ActionId)>> GetRolePermissionsAsync(int roleId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT ModuleId, ActionId
                FROM RolePermissions
                WHERE RoleId = @RoleId;";

            var rows = await connection.QueryAsync<(int ModuleId, int ActionId)>(sql, new { RoleId = roleId });
            return rows.ToHashSet();
        }

        public async Task<List<string>> GetPermittedModuleNamesByRoleAsync(int roleId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT DISTINCT m.ModuleName
                FROM RolePermissions rp
                INNER JOIN Modules m ON rp.ModuleId = m.ModuleId
                WHERE rp.RoleId = @RoleId;";

            var rows = await connection.QueryAsync<string>(sql, new { RoleId = roleId });
            return rows.AsList();
        }

        public async Task<int?> GetUserRoleIdAsync(int userId)
        {
            using var connection = CreateConnection();
            const string sql = "SELECT RoleId FROM Users WHERE UserId = @UserId;";
            return await connection.ExecuteScalarAsync<int?>(sql, new { UserId = userId });
        }

        public async Task<IEnumerable<Role>> GetRolesAsync()
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT 
                    r.RoleId, 
                    r.RoleName, 
                    r.CreatedBy, 
                    r.CreatedAt,
                    COUNT(u.UserId) AS UserCount
                FROM Roles r
                LEFT JOIN Users u ON u.RoleId = r.RoleId
                GROUP BY r.RoleId, r.RoleName, r.CreatedBy, r.CreatedAt
                ORDER BY r.RoleName ASC;";
            return await connection.QueryAsync<Role>(sql);
        }

        public async Task<Role?> GetRoleByIdAsync(int roleId)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT 
                    r.RoleId, 
                    r.RoleName, 
                    r.CreatedBy, 
                    r.CreatedAt,
                    COUNT(u.UserId) AS UserCount
                FROM Roles r
                LEFT JOIN Users u ON u.RoleId = r.RoleId
                WHERE r.RoleId = @RoleId
                GROUP BY r.RoleId, r.RoleName, r.CreatedBy, r.CreatedAt;";
            return await connection.QueryFirstOrDefaultAsync<Role>(sql, new { RoleId = roleId });
        }

        public async Task<Role?> GetRoleByNameAsync(string roleName)
        {
            using var connection = CreateConnection();
            const string sql = @"
                SELECT 
                    r.RoleId, 
                    r.RoleName, 
                    r.CreatedBy, 
                    r.CreatedAt,
                    COUNT(u.UserId) AS UserCount
                FROM Roles r
                LEFT JOIN Users u ON u.RoleId = r.RoleId
                WHERE LOWER(r.RoleName) = LOWER(@RoleName)
                GROUP BY r.RoleId, r.RoleName, r.CreatedBy, r.CreatedAt;";
            return await connection.QueryFirstOrDefaultAsync<Role>(sql, new { RoleName = roleName });
        }

        public async Task<int> CreateRoleAsync(string roleName, int? createdBy, IEnumerable<RolePermissionPair> permissions)
        {
            using var connection = CreateConnection();
            await connection.OpenAsync();
            using var transaction = connection.BeginTransaction();

            try
            {
                const string insertRoleSql = @"
                    INSERT INTO Roles (RoleName, CreatedBy, CreatedAt)
                    OUTPUT INSERTED.RoleId
                    VALUES (@RoleName, @CreatedBy, GETDATE());";

                var roleId = await connection.ExecuteScalarAsync<int>(insertRoleSql, new { RoleName = roleName, CreatedBy = createdBy }, transaction);

                var permissionList = permissions?.ToList() ?? new List<RolePermissionPair>();
                if (permissionList.Any())
                {
                    const string insertPermSql = @"
                        INSERT INTO RolePermissions (RoleId, ModuleId, ActionId)
                        VALUES (@RoleId, @ModuleId, @ActionId);";

                    const string insertAuditSql = @"
                        INSERT INTO PermissionAuditLog (ChangedBy, RoleId, ModuleId, ActionId, Change, Timestamp)
                        VALUES (@ChangedBy, @RoleId, @ModuleId, @ActionId, 'Granted', GETDATE());";

                    foreach (var p in permissionList)
                    {
                        await connection.ExecuteAsync(insertPermSql, new { RoleId = roleId, ModuleId = p.ModuleId, ActionId = p.ActionId }, transaction);
                        await connection.ExecuteAsync(insertAuditSql, new { 
                            ChangedBy = createdBy ?? 0, 
                            RoleId = roleId, 
                            ModuleId = p.ModuleId, 
                            ActionId = p.ActionId 
                        }, transaction);
                    }
                }

                transaction.Commit();
                return roleId;
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public async Task<bool> UpdateRolePermissionsAsync(int roleId, string? roleName, IEnumerable<RolePermissionPair> newPermissions, int changedBy)
        {
            using var connection = CreateConnection();
            await connection.OpenAsync();
            using var transaction = connection.BeginTransaction();

            try
            {
                if (!string.IsNullOrWhiteSpace(roleName))
                {
                    const string updateRoleSql = @"
                        UPDATE Roles 
                        SET RoleName = @RoleName 
                        WHERE RoleId = @RoleId;";
                    await connection.ExecuteAsync(updateRoleSql, new { RoleId = roleId, RoleName = roleName.Trim() }, transaction);
                }

                // 1. Fetch current permissions
                const string selectExistingSql = @"
                    SELECT ModuleId, ActionId
                    FROM RolePermissions
                    WHERE RoleId = @RoleId;";
                var existingRows = (await connection.QueryAsync<(int ModuleId, int ActionId)>(selectExistingSql, new { RoleId = roleId }, transaction)).ToHashSet();

                var newSet = (newPermissions ?? Enumerable.Empty<RolePermissionPair>())
                    .Select(p => (p.ModuleId, p.ActionId))
                    .ToHashSet();

                // 2. Diff sets
                var granted = newSet.Except(existingRows).ToList();
                var revoked = existingRows.Except(newSet).ToList();

                const string insertPermSql = @"
                    INSERT INTO RolePermissions (RoleId, ModuleId, ActionId)
                    VALUES (@RoleId, @ModuleId, @ActionId);";

                const string deletePermSql = @"
                    DELETE FROM RolePermissions
                    WHERE RoleId = @RoleId AND ModuleId = @ModuleId AND ActionId = @ActionId;";

                const string insertAuditSql = @"
                    INSERT INTO PermissionAuditLog (ChangedBy, RoleId, ModuleId, ActionId, Change, Timestamp)
                    VALUES (@ChangedBy, @RoleId, @ModuleId, @ActionId, @Change, GETDATE());";

                // Apply grants
                foreach (var (mId, aId) in granted)
                {
                    await connection.ExecuteAsync(insertPermSql, new { RoleId = roleId, ModuleId = mId, ActionId = aId }, transaction);
                    await connection.ExecuteAsync(insertAuditSql, new { ChangedBy = changedBy, RoleId = roleId, ModuleId = mId, ActionId = aId, Change = "Granted" }, transaction);
                }

                // Apply revocations
                foreach (var (mId, aId) in revoked)
                {
                    await connection.ExecuteAsync(deletePermSql, new { RoleId = roleId, ModuleId = mId, ActionId = aId }, transaction);
                    await connection.ExecuteAsync(insertAuditSql, new { ChangedBy = changedBy, RoleId = roleId, ModuleId = mId, ActionId = aId, Change = "Revoked" }, transaction);
                }

                transaction.Commit();
                return true;
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public async Task<int> GetRoleAssignedUserCountAsync(int roleId)
        {
            using var connection = CreateConnection();
            const string sql = "SELECT COUNT(*) FROM Users WHERE RoleId = @RoleId;";
            return await connection.ExecuteScalarAsync<int>(sql, new { RoleId = roleId });
        }

        public async Task<bool> DeleteRoleAsync(int roleId)
        {
            using var connection = CreateConnection();
            const string sql = "DELETE FROM Roles WHERE RoleId = @RoleId;";
            var rows = await connection.ExecuteAsync(sql, new { RoleId = roleId });
            return rows > 0;
        }

        public async Task WriteAuditLogAsync(int changedBy, int roleId, int moduleId, int actionId, string change)
        {
            using var connection = CreateConnection();
            const string sql = @"
                INSERT INTO PermissionAuditLog (ChangedBy, RoleId, ModuleId, ActionId, Change, Timestamp)
                VALUES (@ChangedBy, @RoleId, @ModuleId, @ActionId, @Change, GETDATE());";
            await connection.ExecuteAsync(sql, new { ChangedBy = changedBy, RoleId = roleId, ModuleId = moduleId, ActionId = actionId, Change = change });
        }
    }
}
