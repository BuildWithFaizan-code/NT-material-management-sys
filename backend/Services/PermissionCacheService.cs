using Microsoft.Extensions.Caching.Memory;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class PermissionCacheService : IPermissionCacheService
    {
        private readonly IMemoryCache _cache;
        private readonly IRolePermissionRepository _repository;
        private readonly ILogger<PermissionCacheService> _logger;
        private static readonly TimeSpan DefaultTtl = TimeSpan.FromMinutes(30);

        public PermissionCacheService(
            IMemoryCache cache,
            IRolePermissionRepository repository,
            ILogger<PermissionCacheService> logger)
        {
            _cache = cache;
            _repository = repository;
            _logger = logger;
        }

        public async Task<bool> HasPermissionAsync(int roleId, int moduleId, int actionId)
        {
            var cacheKey = $"role_perms_{roleId}";

            if (!_cache.TryGetValue<HashSet<(int, int)>>(cacheKey, out var permissions) || permissions == null)
            {
                _logger.LogDebug("Cache miss for RoleId {RoleId} permissions. Loading from repository.", roleId);
                permissions = await _repository.GetRolePermissionsAsync(roleId);

                _cache.Set(cacheKey, permissions, new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = DefaultTtl
                });
            }

            return permissions.Contains((moduleId, actionId));
        }

        public void InvalidateRole(int roleId)
        {
            var cacheKey = $"role_perms_{roleId}";
            _cache.Remove(cacheKey);
            _logger.LogInformation("Invalidated permission cache for RoleId {RoleId}.", roleId);
        }

        public async Task<int?> GetUserRoleIdAsync(int userId)
        {
            var cacheKey = $"user_role_{userId}";

            if (!_cache.TryGetValue<int?>(cacheKey, out var roleId))
            {
                roleId = await _repository.GetUserRoleIdAsync(userId);
                _cache.Set(cacheKey, roleId, new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = DefaultTtl
                });
            }

            return roleId;
        }

        public void InvalidateUser(int userId)
        {
            var cacheKey = $"user_role_{userId}";
            _cache.Remove(cacheKey);
            _logger.LogInformation("Invalidated role cache for UserId {UserId}.", userId);
        }

        public async Task<ModuleItem?> GetModuleByControllerNameAsync(string controllerName)
        {
            var cacheKey = $"module_ctrl_{controllerName.ToLowerInvariant()}";

            if (!_cache.TryGetValue<ModuleItem?>(cacheKey, out var module))
            {
                module = await _repository.GetModuleByControllerNameAsync(controllerName);
                if (module != null)
                {
                    // Reference data is static; store indefinitely in memory
                    _cache.Set(cacheKey, module);
                }
            }

            return module;
        }

        public async Task<ActionItem?> GetActionByHttpVerbAsync(string verb)
        {
            var cacheKey = $"action_verb_{verb.ToUpperInvariant()}";

            if (!_cache.TryGetValue<ActionItem?>(cacheKey, out var action))
            {
                action = await _repository.GetActionByHttpVerbAsync(verb);
                if (action != null)
                {
                    _cache.Set(cacheKey, action);
                }
            }

            return action;
        }
    }
}
