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
        // Updated to support Manager-based filtering
        public async Task<IEnumerable<EmployeeSelectDto>> GetAllEmployees(int? managerId = null)
        {
            var parameters = new DynamicParameters();
            parameters.Add("ManagerID", managerId);

            return await _db.QueryAsync<EmployeeSelectDto>("GetAllEmployeesSimple", parameters);
        }
        public async Task<IEnumerable<AttendanceBreachDto>> GetAttendanceAnalysis(DateTime startDate, DateTime endDate)
        {
            // 1. Get Lateness Policy (Grace Period) via Stored Procedure
            var gracePeriod = await _db.QueryAsync<int?>("GetLatenessGracePeriod", null);
            int grace = gracePeriod.FirstOrDefault() ?? 0;

            // 2. Get Raw Data via Stored Procedure
            var parameters = new DynamicParameters();
            parameters.Add("Start", startDate);
            parameters.Add("End", endDate.AddDays(1)); // Make it inclusive of the end date

            var rawData = await _db.QueryAsync<AttendanceBreachDto>("GetAttendanceAnalysis", parameters);

            // 3. Calculate Logic in C# (Unchanged)
            foreach (var record in rawData)
            {
                // A. Lateness Calculation
                if (record.actual_in > record.shift_start)
                {
                    record.raw_late_minutes = (int)(record.actual_in - record.shift_start).TotalMinutes;
                }
                else
                {
                    record.raw_late_minutes = 0;
                }

                // B. Apply Grace Period
                if (record.raw_late_minutes > 0)
                {
                    if (record.raw_late_minutes <= grace)
                    {
                        record.penalized_late_minutes = 0;
                        record.grace_period_used = record.raw_late_minutes;
                    }
                    else
                    {
                        // Some policies deduct ALL raw minutes if grace is exceeded.
                        // Based on 'Proportional' from sample data, let's assume we penalize the full amount or diff.
                        // Milestone 3 Requirement: Usually 'Late > Grace -> Penalty'.
                        // Let's assume FULL penalty if grace exceeded (common rule).
                        record.penalized_late_minutes = record.raw_late_minutes; 
                        record.grace_period_used = 0;
                    }
                }

                // C. Early Out Calculation
                if (record.actual_out.HasValue && record.actual_out.Value < record.shift_end)
                {
                    record.early_leave_minutes = (int)(record.shift_end - record.actual_out.Value).TotalMinutes;
                }
                else
                {
                    record.early_leave_minutes = 0;
                }
            }

            return rawData;
        }

        // Keep the old method for backward compatibility if needed, or remove if unused.
        public async Task<IEnumerable<AttendanceBreachDto>> GetBreaches(DateTime date)
        {
           return await GetAttendanceAnalysis(date, date);
        }
    }
}