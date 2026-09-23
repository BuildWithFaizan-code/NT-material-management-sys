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
    public class UserManagementController : ControllerBase
    {
        private readonly IUserManagementRepository _userMgmtRepo;
        private readonly IAuthRepository _authRepo;
        private readonly IRolePermissionRepository _roleRepo;
        private readonly IPermissionCacheService _cacheService;
        private readonly ILogger<UserManagementController> _logger;

        public UserManagementController(
            IUserManagementRepository userMgmtRepo,
            IAuthRepository authRepo,
            IRolePermissionRepository roleRepo,
            IPermissionCacheService cacheService,
            ILogger<UserManagementController> logger)
        {
            _userMgmtRepo = userMgmtRepo;
            _authRepo = authRepo;
            _roleRepo = roleRepo;
            _cacheService = cacheService;
            _logger = logger;
        }

        private int GetCurrentUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return int.TryParse(claim, out var id) ? id : 0;
        }

        /// <summary>
        /// GET /api/usermanagement/users
        /// Returns all system users with role names and status.
        /// </summary>
        [HttpGet("users")]
        public async Task<IActionResult> GetAllUsers()
        {
            var users = await _userMgmtRepo.GetAllUsersAsync();
            return Ok(ApiResponse<IEnumerable<UserManagementItemDto>>.Ok(users, "Users fetched successfully."));
        }

        /// <summary>
        /// GET /api/usermanagement/users/{id}
        /// Returns a single user by ID.
        /// </summary>
        [HttpGet("users/{id:int}")]
        public async Task<IActionResult> GetUserById(int id)
        {
            var user = await _userMgmtRepo.GetUserByIdAsync(id);
            if (user == null)
            {
                return NotFound(ApiResponse<string>.Fail($"User with ID #{id} was not found."));
            }
            return Ok(ApiResponse<UserManagementItemDto>.Ok(user, "User fetched successfully."));
        }

        /// <summary>
        /// POST /api/usermanagement/users
        /// Provisions a new user account with assigned role and temporary credentials.
        /// </summary>
        [HttpPost("users")]
        public async Task<IActionResult> CreateUser([FromBody] CreateUserManagementRequest request)
        {
            if (request == null)
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid user creation payload."));
            }

            if (string.IsNullOrWhiteSpace(request.Username))
            {
                return BadRequest(ApiResponse<string>.Fail("Username is required."));
            }

            if (string.IsNullOrWhiteSpace(request.Email))
            {
                return BadRequest(ApiResponse<string>.Fail("Email address is required."));
            }

            var trimmedUsername = request.Username.Trim().ToLowerInvariant();
            var trimmedEmail = request.Email.Trim().ToLowerInvariant();

            // Validate role existence if provided
            if (request.RoleId.HasValue && !request.IsAdmin)
            {
                var role = await _roleRepo.GetRoleByIdAsync(request.RoleId.Value);
                if (role == null)
                {
                    return BadRequest(ApiResponse<string>.Fail($"Role with ID #{request.RoleId.Value} does not exist."));
                }
            }

            // Check username uniqueness
            var existingUser = await _authRepo.GetUserByUsernameAsync(trimmedUsername);
            if (existingUser != null)
            {
                return BadRequest(ApiResponse<string>.Fail($"Username '{trimmedUsername}' is already taken."));
            }

            var password = string.IsNullOrWhiteSpace(request.Password)
                ? $"NtMms@{Guid.NewGuid().ToString("N")[..8]}!"
                : request.Password;

            if (password.Length < 8)
            {
                return BadRequest(ApiResponse<string>.Fail("Password must be at least 8 characters long."));
            }

            var passwordHash = BCrypt.Net.BCrypt.HashPassword(password, workFactor: 11);
            var adminUserId = GetCurrentUserId();

            var newUser = new User
            {
                Username = trimmedUsername,
                Email = trimmedEmail,
                PasswordHash = passwordHash,
                IsActive = true,
                IsAdmin = request.IsAdmin,
                RoleId = request.IsAdmin ? null : request.RoleId,
                MustChangePassword = true,
                CreatedAt = DateTime.UtcNow,
                CreatedBy = adminUserId
            };

            var newUserId = await _authRepo.CreateUserAsync(newUser);

            await _authRepo.WriteAuditLogAsync(new AuthAuditLog
            {
                UserId = newUserId,
                EventType = "UserProvisioned",
                Success = true,
                Detail = $"User '{trimmedUsername}' created by admin ID {adminUserId} with RoleId {request.RoleId}.",
                Timestamp = DateTime.UtcNow
            });

            _logger.LogInformation("Admin {AdminUserId} provisioned user '{Username}' (UserId: {UserId}).", adminUserId, trimmedUsername, newUserId);

            var createdDto = await _userMgmtRepo.GetUserByIdAsync(newUserId);
            return Ok(ApiResponse<UserManagementItemDto>.Ok(createdDto!, "User created successfully."));
        }

        /// <summary>
        /// PUT /api/usermanagement/users/{id}
        /// Updates user properties (email, role, active status).
        /// </summary>
        [HttpPut("users/{id:int}")]
        public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserManagementRequest request)
        {
            if (request == null)
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid update payload."));
            }

            var existing = await _userMgmtRepo.GetUserByIdAsync(id);
            if (existing == null)
            {
                return NotFound(ApiResponse<string>.Fail($"User with ID #{id} was not found."));
            }

            if (request.RoleId.HasValue && !existing.IsAdmin)
            {
                var role = await _roleRepo.GetRoleByIdAsync(request.RoleId.Value);
                if (role == null)
                {
                    return BadRequest(ApiResponse<string>.Fail($"Role with ID #{request.RoleId.Value} does not exist."));
                }
            }

            var email = !string.IsNullOrWhiteSpace(request.Email) ? request.Email.Trim() : existing.Email;
            var roleId = existing.IsAdmin ? null : (request.RoleId ?? existing.RoleId);
            var isActive = request.IsActive ?? existing.IsActive;

            var updated = await _userMgmtRepo.UpdateUserAsync(id, email, roleId, isActive);
            if (!updated)
            {
                return StatusCode(500, ApiResponse<string>.Fail("Failed to update user record in database."));
            }

            // Invalidate user role cache synchronously
            _cacheService.InvalidateUser(id);

            // If user was deactivated, revoke all their active sessions immediately
            if (!isActive && existing.IsActive)
            {
                await _authRepo.RevokeAllSessionsAsync(id);
                _logger.LogInformation("Revoked all active sessions for deactivated User ID {UserId}.", id);
            }

            var updatedDto = await _userMgmtRepo.GetUserByIdAsync(id);
            return Ok(ApiResponse<UserManagementItemDto>.Ok(updatedDto!, "User updated successfully."));
        }

        /// <summary>
        /// PATCH /api/usermanagement/users/{id}/status
        /// Suspends or activates a user. When suspended, immediately revokes all active sessions.
        /// </summary>
        [HttpPatch("users/{id:int}/status")]
        public async Task<IActionResult> SetUserStatus(int id, [FromBody] bool isActive)
        {
            var currentAdminId = GetCurrentUserId();
            if (id == currentAdminId && !isActive)
            {
                return BadRequest(ApiResponse<string>.Fail("You cannot suspend your own administrative account."));
            }

            var existing = await _userMgmtRepo.GetUserByIdAsync(id);
            if (existing == null)
            {
                return NotFound(ApiResponse<string>.Fail($"User with ID #{id} was not found."));
            }

            var updated = await _userMgmtRepo.SetUserActiveStatusAsync(id, isActive);
            if (!updated)
            {
                return StatusCode(500, ApiResponse<string>.Fail("Failed to update user status in database."));
            }

            _cacheService.InvalidateUser(id);

            if (!isActive)
            {
                await _authRepo.RevokeAllSessionsAsync(id);
                _logger.LogInformation("Admin {AdminUserId} suspended User {UserId} and revoked all active sessions.", currentAdminId, id);
            }

            var actionLabel = isActive ? "activated" : "suspended";
            return Ok(ApiResponse<bool>.Ok(isActive, $"User has been {actionLabel} successfully."));
        }

        /// <summary>
        /// DELETE /api/usermanagement/users/{id}
        /// Removes a user account and purges associated sessions.
        /// </summary>
        [HttpDelete("users/{id:int}")]
        public async Task<IActionResult> DeleteUser(int id)
        {
            var currentAdminId = GetCurrentUserId();
            if (id == currentAdminId)
            {
                return BadRequest(ApiResponse<string>.Fail("You cannot remove your own administrative account."));
            }

            var existing = await _userMgmtRepo.GetUserByIdAsync(id);
            if (existing == null)
            {
                return NotFound(ApiResponse<string>.Fail($"User with ID #{id} was not found."));
            }

            // Revoke active sessions first
            await _authRepo.RevokeAllSessionsAsync(id);
            _cacheService.InvalidateUser(id);

            var deleted = await _userMgmtRepo.DeleteUserAsync(id);
            if (!deleted)
            {
                return StatusCode(500, ApiResponse<string>.Fail("Failed to delete user from database."));
            }

            _logger.LogInformation("Admin {AdminUserId} deleted User ID {UserId} ('{Username}').", currentAdminId, id, existing.Username);

            return Ok(ApiResponse<int>.Ok(id, $"User '{existing.Username}' deleted successfully."));
        }
    }
}
