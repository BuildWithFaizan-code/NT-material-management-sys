using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Middleware
{
    /// <summary>
    /// Global convention-based authorization filter.
    /// Maps executing controller to Modules table and HTTP verb to Actions table,
    /// enforcing permission matrix checks via IPermissionCacheService.
    ///
    /// EXECUTION & SECURITY INVARIANTS:
    /// 1. AllowAnonymous endpoints bypass all checks.
    /// 2. Hard exclusions (AuthController, UserManagementController, RolesController, DashboardController)
    ///    are governed by their own [Authorize] / AdminOnly policies.
    /// 3. Authentication verification is performed FIRST before any module/action resolution.
    ///    Unauthenticated calls fail immediately with 401 Unauthorized.
    /// 4. Admin users (IsAdmin = true) bypass module matrix checks IMMEDIATELY after authentication.
    ///    WHY ADMIN BYPASS MUST PRECEDE MODULE RESOLUTION:
    ///    If module resolution ran before admin bypass, any newly introduced controller or module
    ///    seed row missing in the database would lock out administrators with a 403 Forbidden.
    ///    Admins possess blanket operational access across the entire ERP and do not depend on
    ///    the role-permission matrix or database Module seed records.
    /// 5. Non-admin calls fail closed (403 Forbidden) on:
    ///    - User has no RoleId (null)
    ///    - Module not registered in Modules table
    ///    - HTTP verb not recognized in Actions table
    ///    - Role lacks (ModuleId, ActionId) permission
    ///    - Any exception thrown during the evaluation
    /// </summary>
    public class PermissionAuthorizationFilter : IAsyncActionFilter
    {
        private readonly IPermissionCacheService _permissionCacheService;
        private readonly ILogger<PermissionAuthorizationFilter> _logger;

        private static readonly HashSet<string> ExcludedControllers = new(StringComparer.OrdinalIgnoreCase)
        {
            "AuthController",
            "UserManagementController",
            "RolesController",
            "DashboardController"
        };

        public PermissionAuthorizationFilter(
            IPermissionCacheService permissionCacheService,
            ILogger<PermissionAuthorizationFilter> logger)
        {
            _permissionCacheService = permissionCacheService;
            _logger = logger;
        }

        public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
        {
            var controllerName = context.Controller.GetType().Name;

            // 1. Allow explicitly anonymous actions (e.g. login, refresh)
            var endpoint = context.HttpContext.GetEndpoint();
            if (endpoint?.Metadata?.GetMetadata<IAllowAnonymous>() != null)
            {
                await next();
                return;
            }

            // 2. Hard exclusions: dedicated management and auth controllers
            if (ExcludedControllers.Contains(controllerName))
            {
                await next();
                return;
            }

            try
            {
                // 3. Ensure caller is authenticated (401 Unauthorized if false)
                var user = context.HttpContext.User;
                if (user?.Identity?.IsAuthenticated != true)
                {
                    _logger.LogWarning("Fail-Closed: Unauthenticated request to protected controller '{Controller}'.", controllerName);
                    context.Result = new ObjectResult(ApiResponse<string>.Fail("Access denied: Authentication required."))
                    {
                        StatusCode = StatusCodes.Status401Unauthorized
                    };
                    return;
                }

                // 4. Admin bypass check
                // NOTE: Must precede module resolution so administrators are never locked out
                // by missing module seed rows or newly introduced controllers.
                var isAdminClaim = user.FindFirst("isAdmin")?.Value;
                if (string.Equals(isAdminClaim, "true", StringComparison.OrdinalIgnoreCase) || user.IsInRole("Admin"))
                {
                    await next();
                    return;
                }

                // 5. Resolve Module from controller name (403 Forbidden if not found)
                var module = await _permissionCacheService.GetModuleByControllerNameAsync(controllerName);
                if (module == null)
                {
                    _logger.LogWarning("Fail-Closed: Controller '{Controller}' is not registered in the Modules table.", controllerName);
                    context.Result = new ObjectResult(ApiResponse<string>.Fail("Access denied: Module not registered in authorization system."))
                    {
                        StatusCode = StatusCodes.Status403Forbidden
                    };
                    return;
                }

                // 6. Resolve Action from HTTP verb (403 Forbidden if not found)
                var httpMethod = context.HttpContext.Request.Method;
                var action = await _permissionCacheService.GetActionByHttpVerbAsync(httpMethod);
                if (action == null)
                {
                    _logger.LogWarning("Fail-Closed: HTTP verb '{Verb}' on controller '{Controller}' is not mapped to an Action.", httpMethod, controllerName);
                    context.Result = new ObjectResult(ApiResponse<string>.Fail("Access denied: HTTP method not recognized."))
                    {
                        StatusCode = StatusCodes.Status403Forbidden
                    };
                    return;
                }

                // 7. Resolve User's RoleId (403 Forbidden if null/missing)
                var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
                if (!int.TryParse(userIdClaim, out var userId))
                {
                    _logger.LogWarning("Fail-Closed: Invalid or missing NameIdentifier claim for authenticated user.");
                    context.Result = new ObjectResult(ApiResponse<string>.Fail("Access denied: Invalid user credentials."))
                    {
                        StatusCode = StatusCodes.Status403Forbidden
                    };
                    return;
                }

                var roleId = await _permissionCacheService.GetUserRoleIdAsync(userId);
                if (!roleId.HasValue)
                {
                    _logger.LogWarning("Fail-Closed: User {UserId} has no RoleId assigned.", userId);
                    context.Result = new ObjectResult(ApiResponse<string>.Fail("Access denied: No role assigned to your account. Please contact an administrator."))
                    {
                        StatusCode = StatusCodes.Status403Forbidden
                    };
                    return;
                }

                // 8. Check Role Permission Matrix (403 Forbidden if not granted)
                var hasPermission = await _permissionCacheService.HasPermissionAsync(roleId.Value, module.ModuleId, action.ActionId);
                if (!hasPermission)
                {
                    _logger.LogInformation(
                        "Fail-Closed: Permission denied. RoleId {RoleId} lacks {ActionName} permission on module '{ModuleName}'.",
                        roleId.Value, action.ActionName, module.ModuleName);

                    context.Result = new ObjectResult(ApiResponse<string>.Fail("You do not have permission to perform this action."))
                    {
                        StatusCode = StatusCodes.Status403Forbidden
                    };
                    return;
                }

                // Permission granted
                await next();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Fail-Closed: Unexpected error during permission verification for controller '{Controller}'.", controllerName);
                context.Result = new ObjectResult(ApiResponse<string>.Fail("You do not have permission to perform this action."))
                {
                    StatusCode = StatusCodes.Status403Forbidden
                };
            }
        }
    }
}
