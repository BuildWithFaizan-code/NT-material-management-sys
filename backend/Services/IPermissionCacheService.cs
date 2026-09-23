using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IPermissionCacheService
    {
        Task<bool> HasPermissionAsync(int roleId, int moduleId, int actionId);
        Task<List<string>> GetPermittedModulesByRoleAsync(int roleId);
        void InvalidateRole(int roleId);
        Task<int?> GetUserRoleIdAsync(int userId);
        void InvalidateUser(int userId);
        Task<ModuleItem?> GetModuleByControllerNameAsync(string controllerName);
        Task<ActionItem?> GetActionByHttpVerbAsync(string verb);
    }
}
