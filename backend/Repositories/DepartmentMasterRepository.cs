using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class DepartmentMasterRepository : IDepartmentMasterRepository
    {
        private readonly string _connectionString;

        public DepartmentMasterRepository(IConfiguration configuration)
        {
            _connectionString = MMSERP.Api.Common.DbConnectionHelper.ResolveConnectionString(configuration);
        }

        public async Task<IEnumerable<DepartmentMasterDto>> GetAllAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    A.LAB_CODE AS LabCode, 
                    A.LAB_NAME AS LabName, 
                    A.LAB_SERIES AS LabSeries, 
                    CASE 
                        WHEN A.LAB_STATUS = '' OR A.LAB_STATUS IS NULL OR A.LAB_STATUS = 'YES' THEN 'YES' 
                        ELSE 'NO' 
                    END AS LabStatus, 
                    A.LAB_ADD AS LabAdd, 
                    A.LAB_PCODE AS LabPCode, 
                    B.P_NAME AS PName 
                FROM LABOURMST AS A 
                LEFT JOIN PARTYMST AS B ON A.LAB_PCODE = B.P_CODE 
                ORDER BY A.LAB_NAME ASC;";
            return await connection.QueryAsync<DepartmentMasterDto>(sql);
        }

        public async Task<IEnumerable<PartyAccountDto>> GetAccountsAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    P_CODE AS PCode, 
                    P_NAME AS PName 
                FROM PARTYMST 
                ORDER BY P_NAME ASC;";
            return await connection.QueryAsync<PartyAccountDto>(sql);
        }

        public async Task<IEnumerable<PartyAccountLookupDto>> GetAccountsLookupAsync(string search)
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            // Query SELECT * FROM PARTYMST directly - SQL Server returns all columns present on the table!
            const string sql = "SELECT * FROM PARTYMST;";
            var rows = await connection.QueryAsync(sql);

            var result = new List<PartyAccountLookupDto>();

            foreach (IDictionary<string, object> row in rows)
            {
                string GetValue(params string[] possibleKeys)
                {
                    foreach (var key in possibleKeys)
                    {
                        var match = row.FirstOrDefault(kvp => string.Equals(kvp.Key, key, StringComparison.OrdinalIgnoreCase));
                        if (match.Key != null && match.Value != null && DBNull.Value != match.Value)
                        {
                            var val = match.Value.ToString()?.Trim() ?? "";
                            if (val.Length > 0 && val != "-") return val;
                        }
                    }
                    return "";
                }

                int pCode = 0;
                var codeMatch = row.FirstOrDefault(kvp => 
                    string.Equals(kvp.Key, "P_CODE", StringComparison.OrdinalIgnoreCase) || 
                    string.Equals(kvp.Key, "PCODE", StringComparison.OrdinalIgnoreCase) || 
                    string.Equals(kvp.Key, "CODE", StringComparison.OrdinalIgnoreCase));

                if (codeMatch.Key != null && codeMatch.Value != null)
                {
                    int.TryParse(codeMatch.Value.ToString(), out pCode);
                }

                string account = GetValue("P_NAME", "PNAME", "ACCOUNT", "NAME");

                // Mobile Number Mapping (P_MOBILE -> P_GST_MOBILE -> P_OTEL)
                string mobile = GetValue("P_MOBILE", "P_GST_MOBILE", "P_OTEL", "P_MOB", "P_PHNO", "P_PHONE", "MOBILE", "TEL_NO");

                // GSTIN Mapping (P_GST_IN -> P_GSTNo)
                string gstin = GetValue("P_GST_IN", "P_GSTNo", "P_GSTNO", "P_GSTIN", "P_GST", "GST_NO", "GSTNO", "GSTIN");

                // State / Series Mapping (P_GST_STATE)
                string state = GetValue("P_GST_STATE", "P_STATECODE", "P_STCD", "P_STATE", "P_SERIES", "STATE_CODE", "P_CITY", "P_GRP");

                // Address Mapping (P_GST_REGADD -> P_OAdd1 + P_OAdd2 + P_OAdd3 + P_OCity + P_OPinCode -> P_FAdd1)
                string fullAdd = GetValue("P_GST_REGADD");
                if (string.IsNullOrEmpty(fullAdd))
                {
                    string oadd1 = GetValue("P_OAdd1", "P_ADD1", "ADD1");
                    string oadd2 = GetValue("P_OAdd2", "P_ADD2", "ADD2");
                    string oadd3 = GetValue("P_OAdd3", "P_ADD3", "ADD3");
                    string ocity = GetValue("P_OCity", "P_CITY", "CITY");
                    string opin = GetValue("P_OPinCode", "P_PINCODE", "PINCODE");

                    var oParts = new[] { oadd1, oadd2, oadd3, ocity, opin }.Where(s => s.Length > 0).ToList();
                    if (oParts.Count > 0)
                    {
                        fullAdd = string.Join(" ", oParts);
                    }
                    else
                    {
                        fullAdd = GetValue("P_FAdd1", "P_ADDRESS", "ADDRESS", "P_ADD", "LOCATION");
                    }
                }

                // Filter by search query if specified
                if (!string.IsNullOrWhiteSpace(search))
                {
                    var q = search.Trim().ToLower();
                    bool matches = account.ToLower().Contains(q) ||
                                   mobile.ToLower().Contains(q) ||
                                   gstin.ToLower().Contains(q) ||
                                   state.ToLower().Contains(q) ||
                                   fullAdd.ToLower().Contains(q) ||
                                   pCode.ToString().Contains(q);
                    if (!matches) continue;
                }

                result.Add(new PartyAccountLookupDto
                {
                    PartyCode = pCode,
                    AccountName = account,
                    MobileNo = mobile,
                    Gstin = gstin,
                    StateCode = state,
                    Address = fullAdd
                });
            }

            return result.OrderBy(r => r.Account);
        }

        public async Task<DepartmentMasterDto?> GetByCodeAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    A.LAB_CODE AS LabCode, 
                    A.LAB_NAME AS LabName, 
                    A.LAB_SERIES AS LabSeries, 
                    CASE 
                        WHEN A.LAB_STATUS = '' OR A.LAB_STATUS IS NULL OR A.LAB_STATUS = 'YES' THEN 'YES' 
                        ELSE 'NO' 
                    END AS LabStatus, 
                    A.LAB_ADD AS LabAdd, 
                    A.LAB_PCODE AS LabPCode, 
                    B.P_NAME AS PName 
                FROM LABOURMST AS A 
                LEFT JOIN PARTYMST AS B ON A.LAB_PCODE = B.P_CODE 
                WHERE A.LAB_CODE = @Code;";
            return await connection.QueryFirstOrDefaultAsync<DepartmentMasterDto>(sql, new { Code = code });
        }

        public async Task<int> GetNextCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "SELECT ISNULL(MAX(LAB_CODE), 0) + 1 FROM LABOURMST;";
            return await connection.ExecuteScalarAsync<int>(sql);
        }

        public async Task<bool> CreateAsync(CreateDepartmentDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            if (model.LabCode <= 0)
            {
                model.LabCode = await GetNextCodeAsync();
            }

            const string sql = @"
                INSERT INTO LABOURMST (LAB_CODE, LAB_NAME, LAB_SERIES, LAB_STATUS, LAB_ADD, LAB_PCODE) 
                VALUES (@LabCode, @LabName, @LabSeries, @LabStatus, @LabAdd, @LabPCode);";
            var rows = await connection.ExecuteAsync(sql, model);
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(int code, CreateDepartmentDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                UPDATE LABOURMST 
                SET LAB_NAME = @LabName, 
                    LAB_SERIES = @LabSeries, 
                    LAB_STATUS = @LabStatus, 
                    LAB_ADD = @LabAdd, 
                    LAB_PCODE = @LabPCode 
                WHERE LAB_CODE = @LabCode;";
            var rows = await connection.ExecuteAsync(sql, new
            {
                LabCode = code,
                model.LabName,
                model.LabSeries,
                model.LabStatus,
                model.LabAdd,
                model.LabPCode
            });
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "DELETE FROM LABOURMST WHERE LAB_CODE = @Code;";
            var rows = await connection.ExecuteAsync(sql, new { Code = code });
            return rows > 0;
        }
    }
}
