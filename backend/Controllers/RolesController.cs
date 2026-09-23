using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Policy = "AdminOnly")]
    public class RolesController : ControllerBase
    {
        private readonly IRolePermissionRepository _repository;
        private readonly IPermissionCacheService _cacheService;
        private readonly ILogger<RolesController> _logger;

        public RolesController(
            IRolePermissionRepository repository,
            IPermissionCacheService cacheService,
            ILogger<RolesController> logger)
        {
            _repository = repository;
            _cacheService = cacheService;
            _logger = logger;
        }

        private int GetCurrentUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return int.TryParse(claim, out var id) ? id : 0;
        }

        /// <summary>
        /// GET /api/roles
        /// Returns all roles with their assigned user counts.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var roles = await _repository.GetRolesAsync();
            return Ok(ApiResponse<IEnumerable<Role>>.Ok(roles, "Roles fetched successfully."));
        }

        /// <summary>
        /// GET /api/roles/matrix-metadata
        /// Returns all modules and actions for constructing the permission matrix in the UI.
        /// </summary>
        [HttpGet("matrix-metadata")]
        public async Task<IActionResult> GetMatrixMetadata()
        {
            var modules = await _repository.GetAllModulesAsync();
            var actions = await _repository.GetAllActionsAsync();

            var result = new MatrixMetadataDto
            {
                Modules = modules.ToList(),
                Actions = actions.ToList()
            };

            return Ok(ApiResponse<MatrixMetadataDto>.Ok(result, "Matrix metadata fetched successfully."));
        }

        /// <summary>
        /// GET /api/roles/{id}/permissions
        /// Returns role details and its complete set of granted permissions.
        /// </summary>
        [HttpGet("{id:int}/permissions")]
        public async Task<IActionResult> GetPermissions(int id)
        {
            var role = await _repository.GetRoleByIdAsync(id);
            if (role == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Role with ID #{id} was not found."));
            }

            var permissionsSet = await _repository.GetRolePermissionsAsync(id);
            var pairs = permissionsSet.Select(p => new RolePermissionPair
            {
                ModuleId = p.ModuleId,
                ActionId = p.ActionId
            }).ToList();

            var dto = new RoleDetailsDto
            {
                RoleId = role.RoleId,
                RoleName = role.RoleName,
                UserCount = role.UserCount,
                Permissions = pairs
            };

            return Ok(ApiResponse<RoleDetailsDto>.Ok(dto, "Role permissions fetched successfully."));
        }

        /// <summary>
        /// POST /api/roles
        /// Creates a new role with initial permissions in a single transaction.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateRoleRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.RoleName))
            {
                return BadRequest(ApiResponse<string>.Fail("Role name is required."));
            }

            var trimmedName = request.RoleName.Trim();

            // Check name uniqueness
            var existing = await _repository.GetRoleByNameAsync(trimmedName);
            if (existing != null)
            {
                return BadRequest(ApiResponse<string>.Fail($"A role with the name '{trimmedName}' already exists."));
            }

            var adminUserId = GetCurrentUserId();
            var roleId = await _repository.CreateRoleAsync(trimmedName, adminUserId, request.Permissions);

            _logger.LogInformation("Admin {AdminUserId} created role '{RoleName}' with ID {RoleId}.", adminUserId, trimmedName, roleId);

            var createdRole = await _repository.GetRoleByIdAsync(roleId);
            return Ok(ApiResponse<Role>.Ok(createdRole!, "Role created successfully."));
        }

        /// <summary>
        /// PUT /api/roles/{id}/permissions
        /// Updates an existing role's permissions, audit-logs diffs, and synchronously invalidates the role's cache.
        /// </summary>
        [HttpPut("{id:int}/permissions")]
        public async Task<IActionResult> UpdatePermissions(int id, [FromBody] UpdateRolePermissionsRequest request)
        {
            if (request == null)
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid update payload."));
            }

            var role = await _repository.GetRoleByIdAsync(id);
            if (role == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Role with ID #{id} was not found."));
            }

            if (!string.IsNullOrWhiteSpace(request.RoleName))
            {
                var trimmedName = request.RoleName.Trim();
                if (!string.Equals(trimmedName, role.RoleName, StringComparison.OrdinalIgnoreCase))
                {
                    var existing = await _repository.GetRoleByNameAsync(trimmedName);
                    if (existing != null && existing.RoleId != id)
                    {
                        return BadRequest(ApiResponse<string>.Fail($"A role with the name '{trimmedName}' already exists."));
                    }
                }
            }

            var adminUserId = GetCurrentUserId();
            var updated = await _repository.UpdateRolePermissionsAsync(id, request.RoleName, request.Permissions, adminUserId);

            // Synchronously invalidate cache immediately in the same request
            _cacheService.InvalidateRole(id);

            _logger.LogInformation("Admin {AdminUserId} updated permissions for RoleId {RoleId} and invalidated cache.", adminUserId, id);

            return Ok(ApiResponse<bool>.Ok(updated, "Role permissions updated and cache invalidated successfully."));
        }

        /// <summary>
        /// DELETE /api/roles/{id}
        /// Deletes a role only if no users are currently assigned to it.
        /// </summary>
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var role = await _repository.GetRoleByIdAsync(id);
            if (role == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Role with ID #{id} was not found."));
            }

            // In-use check
            var userCount = await _repository.GetRoleAssignedUserCountAsync(id);
            if (userCount > 0)
            {
                return BadRequest(ApiResponse<string>.Fail(
                    $"Cannot delete role '{role.RoleName}' because it is currently assigned to {userCount} user(s). " +
                    "Reassign or remove those users before deleting this role."));
            }

            var deleted = await _repository.DeleteRoleAsync(id);
            if (!deleted)
            {
                return StatusCode(500, ApiResponse<string>.Fail("Failed to delete role from database."));
            }

            _cacheService.InvalidateRole(id);
            _logger.LogInformation("Admin {AdminUserId} deleted RoleId {RoleId} ('{RoleName}').", GetCurrentUserId(), id, role.RoleName);

            return Ok(ApiResponse<int>.Ok(id, $"Role '{role.RoleName}' deleted successfully."));
        }
    }
}
