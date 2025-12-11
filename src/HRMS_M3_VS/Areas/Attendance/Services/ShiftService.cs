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
    }
}