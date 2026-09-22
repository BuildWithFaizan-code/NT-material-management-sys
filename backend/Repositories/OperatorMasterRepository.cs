using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class OperatorMasterRepository : IOperatorMasterRepository
    {
        private readonly string _connectionString;

        public OperatorMasterRepository(IConfiguration configuration)
        {
            _connectionString = MMSERP.Api.Common.DbConnectionHelper.ResolveConnectionString(configuration);
        }

        public async Task<IEnumerable<DepartmentDto>> GetDepartmentsAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    LAB_CODE AS LabCode, 
                    LAB_NAME AS LabName 
                FROM LABOURMST 
                ORDER BY LAB_NAME ASC;";
            return await connection.QueryAsync<DepartmentDto>(sql);
        }

        public async Task<IEnumerable<OperatorMasterDto>> GetAllAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    A.OPER_CODE AS OperCode, 
                    A.OPER_NAME AS OperName, 
                    A.OPER_DEPCD AS OperDepCd, 
                    B.LAB_NAME AS LabName 
                FROM OPERATORMST AS A 
                LEFT JOIN LABOURMST AS B ON A.OPER_DEPCD = B.LAB_CODE 
                ORDER BY A.OPER_CODE ASC;";
            return await connection.QueryAsync<OperatorMasterDto>(sql);
        }

        public async Task<OperatorMasterDto?> GetByCodeAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    A.OPER_CODE AS OperCode, 
                    A.OPER_NAME AS OperName, 
                    A.OPER_DEPCD AS OperDepCd, 
                    B.LAB_NAME AS LabName 
                FROM OPERATORMST AS A 
                LEFT JOIN LABOURMST AS B ON A.OPER_DEPCD = B.LAB_CODE 
                WHERE A.OPER_CODE = @Code;";
            return await connection.QueryFirstOrDefaultAsync<OperatorMasterDto>(sql, new { Code = code });
        }

        public async Task<int> GetNextCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "SELECT ISNULL(MAX(OPER_CODE), 0) + 1 FROM OPERATORMST;";
            return await connection.ExecuteScalarAsync<int>(sql);
        }

        public async Task<bool> CreateAsync(CreateOperatorDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            if (model.OperCode <= 0)
            {
                model.OperCode = await GetNextCodeAsync();
            }

            const string sql = @"
                INSERT INTO OPERATORMST (OPER_CODE, OPER_NAME, OPER_DEPCD) 
                VALUES (@OperCode, @OperName, @OperDepCd);";
            var rows = await connection.ExecuteAsync(sql, model);
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(int code, CreateOperatorDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                UPDATE OPERATORMST 
                SET OPER_NAME = @OperName, 
                    OPER_DEPCD = @OperDepCd 
                WHERE OPER_CODE = @OperCode;";
            var rows = await connection.ExecuteAsync(sql, new { 
                OperCode = code, 
                model.OperName, 
                model.OperDepCd 
            });
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "DELETE FROM OPERATORMST WHERE OPER_CODE = @Code;";
            var rows = await connection.ExecuteAsync(sql, new { Code = code });
            return rows > 0;
        }
    }
}
