using Dapper;
using HRMS_M3_VS.Areas.Employee.Models;
using HRMS_M3_VS.Services;

namespace HRMS_M3_VS.Areas.Employee.Services
{
    public class EmployeeService
    {
        private readonly DbService _db;

        public EmployeeService(DbService db)
        {
            _db = db;
        }

        // Load all employees
        public async Task<IEnumerable<EmployeeDto>> GetAllEmployeesAsync()
        {
            return await _db.QueryAsync<EmployeeDto>("GetAllEmployees", null);
        }

        // Load one employee by ID
        public async Task<EmployeeDto?> GetEmployeeByIdAsync(int employeeId)
        {
            var result = await _db.QueryAsync<EmployeeDto>(
                "ViewEmployeeInfo",
                new { EmployeeID = employeeId }
            );

            return result.FirstOrDefault();
        }

        // Update employee info
        // 1. Updates Email, Address, Phone, Image
        public async Task UpdateEmployeeAsync(EmployeeEditViewModel vm)
        {
            var p = new DynamicParameters();
            p.Add("EmployeeID", vm.EmployeeId);
            p.Add("Email", vm.Email);
            p.Add("Phone", vm.Phone);
            p.Add("Address", vm.Address);
            
            // Explicitly define as Binary with MAX size (-1) to avoid truncation by default mapping
            p.Add("ProfileImage", vm.ExistingImageBytes, System.Data.DbType.Binary, size: -1);

            await _db.ExecuteAsync("UpdateEmployeeInfo", p);
        }

        // 2. Updates Emergency Name, Relation, Phone
        public async Task UpdateEmergencyContactAsync(EmployeeEditViewModel vm)
        {
            await _db.ExecuteAsync("UpdateEmergencyContact", new
            {
                EmployeeID = vm.EmployeeId,
                ContactName = vm.EmergencyContactName,
                Relation = vm.EmergencyRelationship,
                Phone = vm.EmergencyContactPhone
            });
        }
        public async Task<IEnumerable<EmployeeDto>> GetTeamByManagerAsync(int managerId)
        {
            return await _db.QueryAsync<EmployeeDto>(
                "GetTeamByManager",
                new { ManagerID = managerId }
            );
        }
        public async Task<IEnumerable<ProfileCompletenessDto>> GetIncompleteProfilesAsync()
        {
            return await _db.QueryAsync<ProfileCompletenessDto>("GetIncompleteProfiles", null);
        }

    }
}
