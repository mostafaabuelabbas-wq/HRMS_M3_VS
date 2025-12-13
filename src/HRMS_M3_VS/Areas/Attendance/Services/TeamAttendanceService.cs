using Dapper;
using HRMS_M3_VS.Areas.Employee.Models;
using HRMS_M3_VS.Services;
using System.Data;

namespace HRMS_M3_VS.Areas.Employee.Services
{
    public class TeamAttendanceService
    {
        private readonly DbService _db;

        public TeamAttendanceService(DbService db)
        {
            _db = db;
        }

        public async Task<IEnumerable<TeamAttendanceLogDto>> GetTeamAttendance(int managerId, DateTime start, DateTime end)
        {
            var parameters = new DynamicParameters();
            parameters.Add("ManagerID", managerId);
            parameters.Add("DateRangeStart", start);
            parameters.Add("DateRangeEnd", end);

            // Calls your existing SQL Procedure "ViewTeamAttendance"
            return await _db.QueryAsync<TeamAttendanceLogDto>("ViewTeamAttendance", parameters);
        }
    }
}