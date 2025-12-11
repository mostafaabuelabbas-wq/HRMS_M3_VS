using Dapper;
using HRMS_M3_VS.Services;
using HRMS_M3_VS.Areas.Employee.Models;

namespace HRMS_M3_VS.Areas.Employee.Services
{
    public class RoleService
    {
        private readonly DbService _db;

        public RoleService(DbService db)
        {
            _db = db;
        }

        // Load all roles
        public async Task<IEnumerable<RoleDto>> GetRolesAsync()
        {
            return await _db.QueryAsync<RoleDto>("GetAllRoles", null);
        }

        // Assign a role to an employee
        public async Task AssignRoleAsync(int employeeId, int roleId)
        {
            await _db.ExecuteAsync("AssignRole", new
            {
                EmployeeID = employeeId,
                RoleID = roleId
            });
        }

        // Load employees + their roles
        public async Task<IEnumerable<dynamic>> GetAllEmployeesWithRolesAsync()
        {
            return await _db.QueryAsync<dynamic>("GetAllEmployees_Roles", null);
        }
    }
}
