using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IRolePermissionRepository
    {
        Task<ModuleItem?> GetModuleByControllerNameAsync(string controllerName);
        Task<IEnumerable<ModuleItem>> GetAllModulesAsync();
        Task<ActionItem?> GetActionByHttpVerbAsync(string verb);
        Task<IEnumerable<ActionItem>> GetAllActionsAsync();
        Task<HashSet<(int ModuleId, int ActionId)>> GetRolePermissionsAsync(int roleId);
        Task<List<string>> GetPermittedModuleNamesByRoleAsync(int roleId);
        Task<int?> GetUserRoleIdAsync(int userId);
        Task<IEnumerable<Role>> GetRolesAsync();
        Task<Role?> GetRoleByIdAsync(int roleId);
        Task<Role?> GetRoleByNameAsync(string roleName);
        Task<int> CreateRoleAsync(string roleName, int? createdBy, IEnumerable<RolePermissionPair> permissions);
        Task<bool> UpdateRolePermissionsAsync(int roleId, string? roleName, IEnumerable<RolePermissionPair> newPermissions, int changedBy);
        Task<int> GetRoleAssignedUserCountAsync(int roleId);
        Task<bool> DeleteRoleAsync(int roleId);
        Task WriteAuditLogAsync(int changedBy, int roleId, int moduleId, int actionId, string change);
    }
}
