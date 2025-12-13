using Dapper;
using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Services;
using System.Data;

namespace HRMS_M3_VS.Areas.Attendance.Services
{
    public class AttendanceAdminService
    {
        private readonly DbService _db;

        public AttendanceAdminService(DbService db)
        {
            _db = db;
        }

        // 1. Get List of Approved Leaves for Syncing
        public async Task<IEnumerable<LeaveSyncDto>> GetLeavesForSync()
        {
            return await _db.QueryAsync<LeaveSyncDto>("GetApprovedLeavesForSync", null);
        }

        // 2. Perform the Sync Logic
        public async Task<string> SyncLeave(int leaveRequestId)
        {
            var parameters = new DynamicParameters();
            parameters.Add("LeaveRequestID", leaveRequestId);

            var result = await _db.QueryAsync<string>("SyncLeaveToAttendance", parameters);
            return result.FirstOrDefault();
        }
        // Add this method to AttendanceAdminService

        public async Task<string> SyncOfflineRecord(OfflineSyncDto dto)
        {
            var parameters = new DynamicParameters();

            // Mapping to your SQL Procedure "SyncOfflineAttendance"
            parameters.Add("DeviceID", dto.device_id);
            parameters.Add("EmployeeID", dto.employee_id);
            parameters.Add("ClockTime", dto.clock_time);
            parameters.Add("Type", dto.type);

            // Call the procedure directly
            var result = await _db.QueryAsync<string>("SyncOfflineAttendance", parameters);
            return result.FirstOrDefault() ?? "Record synced successfully";
        }

        // Helper to fill the employee dropdown
        public async Task<IEnumerable<EmployeeSelectDto>> GetAllEmployees()
        {
            return await _db.QueryAsync<EmployeeSelectDto>("GetAllEmployeesSimple", null);
        }
        public async Task<IEnumerable<AttendanceBreachDto>> GetBreaches(DateTime date)
        {
            var parameters = new DynamicParameters();
            parameters.Add("Date", date);
            parameters.Add("DepartmentID", null); // Optional: add dropdown later if needed

            return await _db.QueryAsync<AttendanceBreachDto>("GetAttendanceBreaches", parameters);
        }
    }
}