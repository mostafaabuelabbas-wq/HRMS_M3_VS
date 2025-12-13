using System.Data;
using Microsoft.Data.SqlClient;
using Dapper;

namespace HRMS_M3_VS.Services
{
    public class DbService
    {
        private readonly IConfiguration _config;

        public DbService(IConfiguration config)
        {
            _config = config;
        }

        // Query returning multiple rows
        public async Task<IEnumerable<T>> QueryAsync<T>(string storedProcedure, object? parameters)
        {
            using var conn = new SqlConnection(_config.GetConnectionString("HRMS"));
            return await conn.QueryAsync<T>(storedProcedure, parameters, commandType: CommandType.StoredProcedure);
        }

        // Query returning single row
        public async Task<T> QuerySingleAsync<T>(string storedProcedure, object? parameters)
        {
            using var conn = new SqlConnection(_config.GetConnectionString("HRMS"));
            return await conn.QuerySingleAsync<T>(storedProcedure, parameters, commandType: CommandType.StoredProcedure);
        }

        // Execute (INSERT/UPDATE/DELETE)
        public async Task ExecuteAsync(string storedProcedure, object? parameters)
        {
            using var conn = new SqlConnection(_config.GetConnectionString("HRMS"));
            await conn.ExecuteAsync(storedProcedure, parameters, commandType: CommandType.StoredProcedure);
        }

        // ============================================================
        // NEW: Transaction Support
        // ============================================================

        /// <summary>
        /// Execute multiple operations within a single transaction.
        /// If any operation fails, ALL are rolled back.
        /// </summary>
        public async Task ExecuteInTransactionAsync(Func<SqlConnection, SqlTransaction, Task> operations)
        {
            using var conn = new SqlConnection(_config.GetConnectionString("HRMS"));
            await conn.OpenAsync();

            using var transaction = conn.BeginTransaction();

            try
            {
                await operations(conn, transaction);
                await transaction.CommitAsync();
            }
            catch
            {
                await transaction.RollbackAsync();
                throw; // Re-throw the exception so the caller knows it failed
            }
        }
    }
}