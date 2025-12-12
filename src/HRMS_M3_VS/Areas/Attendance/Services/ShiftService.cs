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

        public async Task<IEnumerable<ShiftDto>> GetAllShifts()
        {
            return await _db.QueryAsync<ShiftDto>("GetShiftTypes", null);
        }

        public async Task CreateShift(CreateShiftDto dto)
        {
            var parameters = new DynamicParameters();

            // 1. Output Parameter
            parameters.Add("ShiftID", dbType: DbType.Int32, direction: ParameterDirection.Output);

            // 2. Input Parameters (MAPPING IS KEY HERE)
            // Left side "String" = SQL Parameter Name (Must match SQL exactly)
            // Right side dto.property = C# Value (Must match Model exactly)

            parameters.Add("Name", dto.name);             // SQL: @Name, C#: name
            parameters.Add("Type", dto.type);             // SQL: @Type, C#: type

            // CRITICAL FIXES:
            parameters.Add("Start_Time", dto.start_time); // SQL: @Start_Time, C#: start_time
            parameters.Add("End_Time", dto.end_time);     // SQL: @End_Time, C#: end_time
            parameters.Add("Break_Duration", dto.break_duration); // SQL: @Break_Duration
            parameters.Add("Shift_Date", dto.shift_date); // SQL: @Shift_Date

            parameters.Add("Status", dto.status);

            await _db.ExecuteAsync("CreateShiftType", parameters);
        }
        public async Task<string> ConfigureSplitShift(SplitShiftDto dto)
        {
            var parameters = new DynamicParameters();

            parameters.Add("ShiftName", dto.Name);
            parameters.Add("FirstSlotStart", dto.FirstSlotStart);
            parameters.Add("FirstSlotEnd", dto.FirstSlotEnd);
            parameters.Add("SecondSlotStart", dto.SecondSlotStart);
            parameters.Add("SecondSlotEnd", dto.SecondSlotEnd);

            // FIX: Use QueryAsync (which returns a list) and grab the first result
            var result = await _db.QueryAsync<string>("ConfigureSplitShift", parameters);

            return result.FirstOrDefault();
        }
        // Add these methods to ShiftService.cs

        // 1. Get All Cycles (To show in dropdowns)
        public async Task<IEnumerable<ShiftCycleDto>> GetAllCycles()
        {
            // Make sure your ShiftCycle table has columns: cycle_id, cycle_name, description
            return await _db.QueryAsync<ShiftCycleDto>("GetShiftCycles", null);
            // Note: Using Text query here for simplicity since we didn't make a proc for "ViewCycles"
        }

        // 2. Create a new Cycle
        public async Task CreateShiftCycle(ShiftCycleDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("CycleID", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("CycleName", dto.CycleName);
            parameters.Add("Description", dto.Description);

            await _db.ExecuteAsync("CreateShiftCycle", parameters);
        }

        // 3. Add Shift to Cycle
        public async Task<string> AddShiftToCycle(AddToCycleDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("CycleID", dto.CycleId);
            parameters.Add("ShiftID", dto.ShiftId);
            parameters.Add("OrderNumber", dto.OrderNumber);

            // This procedure returns a message string
            var result = await _db.QueryAsync<string>("AddShiftToCycle", parameters);
            return result.FirstOrDefault();
        }
    }
}