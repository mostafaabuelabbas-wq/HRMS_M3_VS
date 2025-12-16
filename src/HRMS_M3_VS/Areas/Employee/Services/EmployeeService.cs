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
            await _db.ExecuteAsync("UpdateEmployeeInfo", new
            {
                EmployeeID = vm.EmployeeId,
                Email = vm.Email,
                Phone = vm.Phone,
                Address = vm.Address,
                ProfileImage = vm.ExistingImageBytes
            });
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
