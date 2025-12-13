using Dapper;
using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Services;
using System.Data;

namespace HRMS_M3_VS.Areas.Attendance.Services
{
    public class ShiftService
    {
        private readonly DbService _db;

        public ShiftService(DbService db)
        {
            _db = db;
        }

        // --- 1. Get Lists ---
        public async Task<IEnumerable<ShiftDto>> GetAllShifts()
        {
            return await _db.QueryAsync<ShiftDto>("GetShiftTypes", null);
        }

        public async Task<IEnumerable<ShiftCycleDto>> GetAllCycles()
        {
            // Using raw SQL to ensure we get the list correctly for the dropdown
            string sql = "SELECT * FROM ShiftCycle";
            return await _db.QueryAsync<ShiftCycleDto>("GetShiftCycles", null);
        }

        // --- 2. Create Standard Shift ---
        public async Task CreateShift(CreateShiftDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("ShiftID", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("Name", dto.name);
            parameters.Add("Type", dto.type);
            parameters.Add("Start_Time", dto.start_time);
            parameters.Add("End_Time", dto.end_time);
            parameters.Add("Break_Duration", dto.break_duration);
            parameters.Add("Shift_Date", dto.shift_date);
            parameters.Add("Status", dto.status);

            await _db.ExecuteAsync("CreateShiftType", parameters);
        }

        // --- 3. Configure Split Shift ---
        public async Task<string> ConfigureSplitShift(SplitShiftDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("ShiftName", dto.Name);
            parameters.Add("FirstSlotStart", dto.FirstSlotStart);
            parameters.Add("FirstSlotEnd", dto.FirstSlotEnd);
            parameters.Add("SecondSlotStart", dto.SecondSlotStart);
            parameters.Add("SecondSlotEnd", dto.SecondSlotEnd);

            var result = await _db.QueryAsync<string>("ConfigureSplitShift", parameters);
            return result.FirstOrDefault();
        }

        // --- 4. Create Cycle ---
        public async Task CreateShiftCycle(ShiftCycleDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("CycleID", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("CycleName", dto.cycle_name); // Map C# snake_case to SQL Param
            parameters.Add("Description", dto.description);

            await _db.ExecuteAsync("CreateShiftCycle", parameters);
        }

        // --- 5. Link Shift to Cycle ---
        public async Task<string> AddShiftToCycle(AddToCycleDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("CycleID", dto.cycle_id);
            parameters.Add("ShiftID", dto.shift_id);
            parameters.Add("OrderNumber", dto.order_number);

            var result = await _db.QueryAsync<string>("AddShiftToCycle", parameters);
            return result.FirstOrDefault();
        }
        // --- Dropdown Helpers ---
        public async Task<IEnumerable<EmployeeSelectDto>> GetAllEmployees()
        {
            // Use the simple helper proc we created in Step 1
            return await _db.QueryAsync<EmployeeSelectDto>("GetAllEmployeesSimple", null);
        }

        public async Task<IEnumerable<DepartmentSelectDto>> GetAllDepartments()
        {
            // Use the simple helper proc we created in Step 1
            return await _db.QueryAsync<DepartmentSelectDto>("GetAllDepartments", null);
        }

        // --- Assign To Employee ---
        public async Task<string> AssignToEmployee(AssignToEmployeeDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("EmployeeID", dto.employee_id);
            parameters.Add("ShiftID", dto.shift_id);
            parameters.Add("StartDate", dto.start_date);
            parameters.Add("EndDate", dto.end_date);

            // We use QueryAsync because your proc returns a SELECT message
            var result = await _db.QueryAsync<string>("AssignShiftToEmployee", parameters);
            return result.FirstOrDefault();
        }

        // --- Assign To Department ---
        public async Task<string> AssignToDepartment(AssignToDepartmentDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("DepartmentID", dto.department_id);
            parameters.Add("ShiftID", dto.shift_id);
            parameters.Add("StartDate", dto.start_date);
            parameters.Add("EndDate", dto.end_date);

            var result = await _db.QueryAsync<string>("AssignShiftToDepartment", parameters);
            return result.FirstOrDefault();
        }
        // --- Assign Rotational Shift ---
        public async Task<string> AssignRotationalShift(AssignRotationalDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("EmployeeID", dto.employee_id);
            parameters.Add("ShiftCycle", dto.cycle_id);
            parameters.Add("StartDate", dto.start_date);
            parameters.Add("EndDate", dto.end_date);
            parameters.Add("Status", "Active");

            var result = await _db.QueryAsync<string>("AssignRotationalShift", parameters);
            return result.FirstOrDefault();
        }

        // --- Assign Custom Shift ---
        public async Task<string> AssignCustomShift(AssignCustomDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("EmployeeID", dto.employee_id);
            parameters.Add("ShiftName", dto.shift_name);
            parameters.Add("ShiftType", dto.shift_type);
            parameters.Add("StartTime", dto.start_time);
            parameters.Add("EndTime", dto.end_time);
            parameters.Add("StartDate", dto.start_date);
            parameters.Add("EndDate", dto.end_date);

            var result = await _db.QueryAsync<string>("AssignCustomShift", parameters);
            return result.FirstOrDefault();
        }

    }
}