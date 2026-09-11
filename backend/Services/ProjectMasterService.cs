using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class ProjectMasterService : IProjectMasterService
    {
        private readonly IProjectMasterRepository _repository;

        public ProjectMasterService(IProjectMasterRepository repository)
        {
            _repository = repository;
        }

        public async Task<IEnumerable<ProjectMasterDto>> GetAllAsync()
        {
            return await _repository.GetAllAsync();
        }

        public async Task<int> GetNextCodeAsync()
        {
            return await _repository.GetNextCodeAsync();
        }

        public async Task<bool> CreateAsync(ProjectMasterDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.PrjName))
            {
                throw new ArgumentException("Project description cannot be empty.");
            }
            return await _repository.CreateAsync(dto);
        }

        public async Task<bool> UpdateAsync(ProjectMasterDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.PrjName))
            {
                throw new ArgumentException("Project description cannot be empty.");
            }
            return await _repository.UpdateAsync(dto);
        }

        public async Task<bool> DeleteAsync(int code)
        {
            return await _repository.DeleteAsync(code);
        }
    }
}
