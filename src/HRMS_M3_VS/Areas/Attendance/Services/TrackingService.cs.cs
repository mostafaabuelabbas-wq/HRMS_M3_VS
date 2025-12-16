using Dapper;
using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Services;
using System.Data;

namespace HRMS_M3_VS.Areas.Attendance.Services
{
    public class TrackingService
    {
        private readonly DbService _db;

        public TrackingService(DbService db)
        {
            _db = db;
        }

        // 1. Get History (Calls the NEW procedure we made)
        public async Task<IEnumerable<AttendanceLogDto>> GetMyAttendance(int employeeId)
        {
            var parameters = new DynamicParameters();
            parameters.Add("EmployeeID", employeeId);
            return await _db.QueryAsync<AttendanceLogDto>("GetMyAttendance", parameters);
        }

        // 2. Record Manual Entry (Calls User Story 5.3)
        public async Task<string> RecordAttendance(RecordAttendanceDto dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("EmployeeID", dto.employee_id);
            parameters.Add("ShiftID", dto.shift_id);
            parameters.Add("EntryTime", dto.entry_time);
            parameters.Add("ExitTime", dto.exit_time);

            // User Story 5.3 returns a confirmation message
            var result = await _db.QueryAsync<string>("RecordAttendance", parameters);
            return result.FirstOrDefault();
        }

        // 3. Get Shifts for Dropdown (Calls User Story 5.6)
        public async Task<IEnumerable<ShiftDto>> GetMyShifts(int employeeId)
        {
            var parameters = new DynamicParameters();
            parameters.Add("EmployeeID", employeeId);
            // This maps to the columns returned by ViewAssignedShifts
            return await _db.QueryAsync<ShiftDto>("ViewAssignedShifts", parameters);
        }
        // Add this inside TrackingService class

        public async Task<string> SubmitCorrection(CorrectionRequestDto dto)
        {
            var parameters = new DynamicParameters();

            // MAPPING: SQL Parameter Name (Left) = C# Value (Right)
            parameters.Add("EmployeeID", dto.employee_id);
            parameters.Add("Date", dto.date);
            parameters.Add("CorrectionType", dto.correction_type);
            parameters.Add("Reason", dto.reason);

            // Your procedure returns a SELECT 'Message', so we use QueryAsync to get that string
            var result = await _db.QueryAsync<string>("SubmitCorrectionRequest", parameters);

            return result.FirstOrDefault();
        }

        // 5. Real-Time Punch (ClockIn/ClockOut)
        public async Task<string> RecordPunch(int employeeId, DateTime time, string type)
        {
            var parameters = new DynamicParameters();
            parameters.Add("EmployeeID", employeeId);
            parameters.Add("ClockInOutTime", time);
            parameters.Add("Type", type);

            var result = await _db.QueryAsync<string>("RecordMultiplePunches", parameters);
            return result.FirstOrDefault();
        }
    }
}