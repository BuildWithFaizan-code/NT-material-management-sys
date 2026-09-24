namespace MMSERP.Api.Models
{
    public class Role
    {
        public int RoleId { get; set; }
        public string RoleName { get; set; } = string.Empty;
        public int? CreatedBy { get; set; }
        public DateTime CreatedAt { get; set; }
        public int UserCount { get; set; }
    }

    public class ModuleItem
    {
        public int ModuleId { get; set; }
        public string ModuleName { get; set; } = string.Empty;
        public string ModuleGroup { get; set; } = string.Empty;
        public string ControllerName { get; set; } = string.Empty;
    }

    public class ActionItem
    {
        public int ActionId { get; set; }
        public string ActionName { get; set; } = string.Empty;
        public string HttpVerb { get; set; } = string.Empty;
    }

    public class RolePermissionPair
    {
        public int ModuleId { get; set; }
        public int ActionId { get; set; }
    }

    public class RoleDetailsDto
    {
        public int RoleId { get; set; }
        public string RoleName { get; set; } = string.Empty;
        public int UserCount { get; set; }
        public List<RolePermissionPair> Permissions { get; set; } = new();
    }

    public class CreateRoleRequest
    {
        public string RoleName { get; set; } = string.Empty;
        public List<RolePermissionPair> Permissions { get; set; } = new();
    }

    public class UpdateRolePermissionsRequest
    {
        public string? RoleName { get; set; }
        public List<RolePermissionPair> Permissions { get; set; } = new();
    }

    public class MatrixMetadataDto
    {
        public List<ModuleItem> Modules { get; set; } = new();
        public List<ActionItem> Actions { get; set; } = new();
    }

    public class UserManagementItemDto
    {
        public int UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public bool IsAdmin { get; set; }
        public int? RoleId { get; set; }
        public string? RoleName { get; set; }
        public DateTime? LastLoginAt { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class CreateUserManagementRequest
    {
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Password { get; set; }
        public int? RoleId { get; set; }
        public bool IsAdmin { get; set; }
    }

    public class UpdateUserManagementRequest
    {
        public string? Email { get; set; }
        public int? RoleId { get; set; }
        public bool? IsActive { get; set; }
    }

    public class MyPermissionItemDto
    {
        public int ModuleId { get; set; }
        public int ActionId { get; set; }
        public string ModuleName { get; set; } = string.Empty;
        public string ActionName { get; set; } = string.Empty;
        public string ControllerName { get; set; } = string.Empty;
    }

    public class MyPermissionsResponseDto
    {
        public bool IsAdmin { get; set; }
        public int? RoleId { get; set; }
        public List<MyPermissionItemDto> Permissions { get; set; } = new();
    }
}
