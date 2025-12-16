using Dapper;
using HRMS_M3_VS.Areas.Leave.Models;
using HRMS_M3_VS.Services;
using System.Data;

namespace HRMS_M3_VS.Areas.Leave.Services
{
    public class LeaveService
    {
        private readonly DbService _db;

        public LeaveService(DbService db) { _db = db; }

        // --- Manager Features ---
        public async Task<IEnumerable<PendingLeaveRequestDto>> GetPendingLeaveRequests(int managerId)
        {
            return await _db.QueryAsync<PendingLeaveRequestDto>("GetPendingLeaveRequests", new { ManagerID = managerId });
        }

        /// <summary>
        /// Get ALL leave requests for HR Admin (not just pending)
        /// </summary>
        public async Task<IEnumerable<PendingLeaveRequestDto>> GetAllLeaveRequests()
        {
            return await _db.QueryAsync<PendingLeaveRequestDto>("GetAllLeaveRequests", null);
        }


        public async Task<string> ApproveLeaveRequest(int id, int managerId)
        {
            // Call the approval stored procedure
            await _db.ExecuteAsync("ApproveLeaveRequest", new
            {
                LeaveRequestID = id,
                ApproverID = managerId,
                Status = "Approved"
            });

            // ✅ NEW: After approval succeeds, sync to attendance
            try
            {
                await _db.ExecuteAsync("SyncLeaveToAttendance", new
                {
                    LeaveRequestID = id
                });
            }
            catch (Exception ex)
            {
                // If sync fails, log it but don't fail the approval
                // The leave is already approved, sync can be done manually if needed
                Console.WriteLine($"Attendance sync failed: {ex.Message}");
            }

            return "Leave request approved successfully and synced to attendance.";
        }
        public async Task<string> RejectLeaveRequest(int id, int managerId, string reason)
        {
            await _db.ExecuteAsync("ApproveLeaveRequest", new
            {
                LeaveRequestID = id,
                ApproverID = managerId,
                Status = "Rejected",
                Reason = reason  // ✅ Pass reason for reject
            });

            return "Rejected successfully.";
        }
        public async Task<string> FlagIrregularLeave(int empId, int mgrId, string reason)
        {
            var res = await _db.QueryAsync<string>("FlagIrregularLeave", new { EmployeeID = empId, ManagerID = mgrId, PatternDescription = reason });
            return res.FirstOrDefault() ?? "Flagged.";
        }

        // --- Employee Features ---
        public async Task<IEnumerable<LeaveTypeDropdownDto>> GetLeaveTypesForDropdown()
        {
            return await _db.QueryAsync<LeaveTypeDropdownDto>("GetLeaveTypes", null);
        }

        // ✅ UPDATED: Submit Leave Request with File Attachment
        public async Task SubmitLeaveRequest(int employeeId, LeaveApplyDto dto)
        {
            var result = await _db.QueryAsync<dynamic>(
                "SubmitLeaveRequest",
                new
                {
                    EmployeeID = employeeId,
                    LeaveTypeID = dto.leave_id,
                    StartDate = dto.start_date,
                    EndDate = dto.end_date,
                    Reason = dto.justification
                }
            );

            var row = result.FirstOrDefault();

            if (row == null) throw new Exception("Database returned no response.");

            // ✅ SAFE CONVERSION: Handles nulls and decimals gracefully
            int newRequestId = 0;
            if (row.NewRequestId != null)
            {
                newRequestId = Convert.ToInt32(row.NewRequestId);
            }

            // Check if SQL returned an error message (Validation logic)
            // If ID is 0, it means validation failed in SQL (e.g. Not Enough Balance)
            if (newRequestId == 0)
            {
                string msg = "Submission failed.";
                try { msg = (string)row.ConfirmationMessage; } catch { } // Try to get SQL error message
                throw new Exception(msg);
            }

            // ✅ NEW: Handle Attachment (Only if we have a valid ID)
            if (dto.attachment != null && dto.attachment.Length > 0 && newRequestId > 0)
            {
                var uploadFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "leaves");
                if (!Directory.Exists(uploadFolder)) Directory.CreateDirectory(uploadFolder);

                var uniqueFileName = Guid.NewGuid().ToString() + "_" + Path.GetFileName(dto.attachment.FileName);
                var filePath = Path.Combine(uploadFolder, uniqueFileName);

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await dto.attachment.CopyToAsync(stream);
                }

                // Save to database using the stored procedure
                await _db.ExecuteAsync("InsertLeaveDocument", new
                {
                    LeaveRequestID = newRequestId,
                    FilePath = "/uploads/leaves/" + uniqueFileName
                });
            }
        }

        // ✅ NEW: Get Attachments for a Leave Request
        public async Task<IEnumerable<LeaveDocumentDto>> GetLeaveAttachments(int requestId)
        {
            var sql = @"
                SELECT 
                    document_id AS DocumentId,
                    leave_request_id AS LeaveRequestId,
                    file_path AS FilePath,
                    uploaded_at AS UploadedAt
                FROM LeaveDocument
                WHERE leave_request_id = @RequestId
                ORDER BY uploaded_at DESC";

            return await _db.QueryAsync<LeaveDocumentDto>(sql, new { RequestId = requestId });
        }

        // --- Other Getters ---
        public async Task<IEnumerable<LeaveBalanceDto>> GetEmployeeBalance(int id)
        {
            return await _db.QueryAsync<LeaveBalanceDto>("GetLeaveBalance", new { EmployeeID = id });
        }

        public async Task<IEnumerable<LeaveHistoryDto>> GetEmployeeHistory(int id)
        {
            return await _db.QueryAsync<LeaveHistoryDto>("ViewLeaveHistory", new { EmployeeID = id });
        }

        // ✅ NEW: Get History with Attachment Count
        public async Task<IEnumerable<LeaveHistoryWithAttachmentsDto>> GetEmployeeHistoryWithAttachments(int id)
        {
            // ✅ Now uses YOUR existing ViewLeaveHistory procedure!
            return await _db.QueryAsync<LeaveHistoryWithAttachmentsDto>(
                "ViewLeaveHistory",  // Your existing procedure name
                new { EmployeeID = id }
            );
        }

        // --- HR Admin (Configuration) ---

        public async Task<IEnumerable<LeaveConfigDto>> GetLeaveConfigurations()
        {
            // Requires SQL Procedure: GetLeaveConfiguration
            var result = await _db.QueryAsync<dynamic>("GetLeaveConfiguration", null);

            return result.Select(r => new LeaveConfigDto
            {
                leave_id = r.leave_id,
                leave_type = r.leave_type,
                leave_description = r.leave_description,
                notice_period = r.notice_period ?? 0,
                max_duration = r.max_duration ?? 0,
                eligibility_rules = r.eligibility_rules ?? "All"
            });
        }

        public async Task<string> SaveLeaveConfiguration(LeaveConfigDto dto)
        {
            // 1. Create/Update Type
            await _db.ExecuteAsync("ManageLeaveTypes", new
            {
                LeaveType = dto.leave_type,
                Description = dto.leave_description
            });

            // 2. Configure Rules
            await _db.ExecuteAsync("ConfigureLeaveRules", new
            {
                LeaveType = dto.leave_type,
                MaxDuration = dto.max_duration,
                NoticePeriod = dto.notice_period,
                WorkflowType = dto.workflow_type
            });

            // 3. Configure Eligibility
            await _db.ExecuteAsync("ConfigureLeaveEligibility", new
            {
                LeaveType = dto.leave_type,
                MinTenure = 0,
                EmployeeType = dto.eligibility_rules
            });

            return "Configuration saved successfully.";
        }

        // ==========================================================
        // HR ADMIN: ASSIGN ENTITLEMENTS
        // ==========================================================

        public async Task<IEnumerable<EmployeeSimpleDto>> GetAllEmployees()
        {
            return await _db.QueryAsync<EmployeeSimpleDto>("GetAllEmployeesSimple", null);
        }

        public async Task<string> AssignEntitlement(AssignEntitlementDto dto)
        {
            var result = await _db.QueryAsync<dynamic>(
                "AssignLeaveEntitlement",
                new
                {
                    EmployeeID = dto.EmployeeId,
                    LeaveTypeID = dto.LeaveTypeId,
                    Entitlement = dto.Entitlement
                }
            );
            return result.FirstOrDefault()?.ConfirmationMessage ?? "Entitlement updated.";
        }
        /// <summary>
        /// HR Admin can override a leave decision (flip approved/rejected)
        /// </summary>
        public async Task<string> OverrideLeaveDecision(int requestId, string reason)
        {
            try
            {
                await _db.ExecuteAsync("OverrideLeaveDecision", new
                {
                    LeaveRequestID = requestId,
                    Reason = reason
                });

                return "Leave decision overridden successfully.";
            }
            catch (Exception ex)
            {
                throw new Exception($"Override failed: {ex.Message}");
            }
        }
    }
}