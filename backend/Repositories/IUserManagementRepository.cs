using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IUserManagementRepository
    {
        Task<IEnumerable<UserManagementItemDto>> GetAllUsersAsync();
        Task<UserManagementItemDto?> GetUserByIdAsync(int userId);
        Task<bool> UpdateUserAsync(int userId, string email, int? roleId, bool isActive);
        Task<bool> SetUserActiveStatusAsync(int userId, bool isActive);
        Task<bool> DeleteUserAsync(int userId);
    }
}
