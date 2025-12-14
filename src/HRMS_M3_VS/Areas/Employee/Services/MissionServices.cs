using Dapper;
using HRMS_M3_VS.Areas.Employee.Models;
using HRMS_M3_VS.Services;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace HRMS_M3_VS.Areas.Employee.Services
{
    public class MissionService
    {
        private readonly DbService _db;

        public MissionService(DbService db)
        {
            _db = db;
        }

        // 1. Get Missions (Smart logic handled in SQL)
        public async Task<IEnumerable<MissionDto>> GetMissionsAsync(int userId, string role)
        {
            // If user is HR, we send "HRAdmin" to see everything, otherwise "Manager" or "Employee"
            return await _db.QueryAsync<MissionDto>("ViewMissionsByRole", new
            {
                UserID = userId,
                Role = role
            });
        }

        // 2. Assign Mission
        public async Task AssignMissionAsync(MissionCreateViewModel vm)
        {
            await _db.ExecuteAsync("AssignMission", new
            {
                EmployeeID = vm.EmployeeId,
                ManagerID = 0, // SEND DUMMY VALUE (SQL calculates real one)
                Destination = vm.Destination,
                Description = vm.Description,
                StartDate = vm.StartDate,
                EndDate = vm.EndDate
            });
        }

        // 3. Update Status
        public async Task UpdateStatusAsync(int missionId, string status)
        {
            await _db.ExecuteAsync("UpdateMissionStatus", new { MissionID = missionId, Status = status });
        }

        // 4. Helper for Dropdowns (Get all employees)
        public async Task<IEnumerable<SelectListItem>> GetUserListAsync()
        {
            // Use the Stored Procedure name, not raw SQL
            var list = await _db.QueryAsync<dynamic>("GetEmployeeSimpleList", null);
            return list.Select(e => new SelectListItem
            {
                Value = e.employee_id.ToString(),
                Text = e.full_name
            });
        }
    }
}