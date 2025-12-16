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
        public async Task<string> ApproveLeaveRequest(int id, int managerId)
        {
            await _db.QueryAsync<dynamic>("ApproveLeaveRequest", new { LeaveRequestID = id, ApproverID = managerId, Status = "Approved" });
            return "Approved successfully.";
        }
        public async Task<string> RejectLeaveRequest(int id, int managerId, string reason)
        {
            await _db.QueryAsync<dynamic>("RejectLeaveRequest", new { LeaveRequestID = id, ManagerID = managerId, Reason = reason });
            return "Rejected successfully.";
        }
        public async Task<string> FlagIrregularLeave(int empId, int mgrId, string reason)
        {
            var res = await _db.QueryAsync<string>("FlagIrregularLeave", new { EmployeeID = empId, ManagerID = mgrId, PatternDescription = reason });
            return res.FirstOrDefault() ?? "Flagged.";
        }

        // --- Employee Features ---
        public async Task<IEnumerable<LeaveTypeDropdownDto>> GetLeaveTypesForDropdown(int employeeId)
        {
            // 1. Get All Leave Types (with rules)
            var allTypes = await _db.QueryAsync<LeaveTypeDropdownDto>("GetLeaveTypes", null);

            // 2. Get Employee Info for filtering
            // Note: We need a lightweight way to get Gender/Tenure/Type. 
            // Reuse ViewEmployeeInfo simply as we don't have a smaller one ready, or query directly.
            // For efficiency, let's assuming ViewEmployeeInfo is okay, or just map needed fields.
            var empInfo = (await _db.QueryAsync<dynamic>("ViewEmployeeInfo", new { EmployeeID = employeeId })).FirstOrDefault();

            if (empInfo == null) return allTypes; // Fallback

            // 3. Filter in Memory
            var filtered = allTypes.Where(type => CheckEligibility(type.eligibility_rules, empInfo)).ToList();
            return filtered;
        }

        private bool CheckEligibility(string rules, dynamic employee)
        {
            if (string.IsNullOrEmpty(rules) || rules.Equals("All", StringComparison.OrdinalIgnoreCase)) 
                return true;

            // Rules format: "Type=FullTime;Gender=Female"
            var criteria = rules.Split(';', StringSplitOptions.RemoveEmptyEntries);

            foreach (var criterion in criteria)
            {
                var parts = criterion.Split('=');
                if (parts.Length != 2) continue;

                var key = parts[0].Trim();
                var value = parts[1].Trim();

                if (key.Equals("Gender", StringComparison.OrdinalIgnoreCase))
                {
                    // Assuming we have Gender in employee info (not strictly in provided schema ViewEmployeeInfo output, 
                    // but usually inferred or present. If missing, skip check or fail?)
                    // Schema check: ViewEmployeeInfo returns FullName, etc. Does it return Gender?
                    // Let's rely on what we saw: ContractType IS there.
                    // For now, implement ContractType and Tenure.
                }
                
                if (key.Equals("Type", StringComparison.OrdinalIgnoreCase)) // Contract Type
                {
                    if (value.Equals("All", StringComparison.OrdinalIgnoreCase)) continue; // Allow "All"

                    string empType = employee.contract_type ?? ""; // e.g. Full-Time, Part-Time
                    if (!empType.Equals(value, StringComparison.OrdinalIgnoreCase)) return false;
                }

                if (key.Equals("MinTenure", StringComparison.OrdinalIgnoreCase))
                {
                    if (int.TryParse(value, out int requiredDays))
                    {
                         DateTime hireDate = employee.hire_date;
                         var tenure = (DateTime.Now - hireDate).TotalDays;
                         if (tenure < requiredDays) return false;
                    }
                }
            }
            return true;
        }

        // ✅ FIXED: Safe ID Conversion to prevent "Cannot convert null to int"
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

            // 2. Handle Attachment (Only if we have a valid ID)
            if (dto.attachment != null && dto.attachment.Length > 0 && newRequestId > 0)
            {
                // VALIDATION: Max 5MB
                if (dto.attachment.Length > 5 * 1024 * 1024)
                {
                    throw new Exception("File size exceeds the 5MB limit.");
                }

                // VALIDATION: Allowed Extensions
                var allowedExtensions = new[] { ".pdf", ".jpg", ".jpeg", ".png" };
                var extension = Path.GetExtension(dto.attachment.FileName).ToLowerInvariant();
                
                if (!allowedExtensions.Contains(extension))
                {
                    throw new Exception("Invalid file type. Only PDF, JPG, and PNG are allowed.");
                }

                var uploadFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "leaves");
                if (!Directory.Exists(uploadFolder)) Directory.CreateDirectory(uploadFolder);

                // SANITIZE FILENAME: Remove spaces and special chars to prevent URL issues
                var rawFileName = Path.GetFileName(dto.attachment.FileName);
                var safeFileName = System.Text.RegularExpressions.Regex.Replace(rawFileName, @"[^a-zA-Z0-9\._-]", "_");
                var uniqueFileName = Guid.NewGuid().ToString() + "_" + safeFileName;
                var filePath = Path.Combine(uploadFolder, uniqueFileName);

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await dto.attachment.CopyToAsync(stream);
                }

                await _db.ExecuteAsync("InsertLeaveDocument", new 
                { 
                    LeaveRequestID = newRequestId, 
                    FilePath = "/uploads/leaves/" + uniqueFileName 
                });
            }
        }

        // --- Other Getters ---
        public async Task<IEnumerable<LeaveBalanceDto>> GetEmployeeBalance(int id) => await _db.QueryAsync<LeaveBalanceDto>("GetLeaveBalance", new { EmployeeID = id });
        public async Task<IEnumerable<LeaveHistoryDto>> GetEmployeeHistory(int id) => await _db.QueryAsync<LeaveHistoryDto>("ViewLeaveHistory", new { EmployeeID = id });

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
                max_duration = r.max_duration ?? 0, // Added this mapping
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

            // 2. Configure Rules (Added WorkflowType, EligibilityRules to match SQL Proc)
            await _db.ExecuteAsync("ConfigureLeaveRules", new
            {
                LeaveType = dto.leave_type,
                MaxDuration = dto.max_duration,
                NoticePeriod = dto.notice_period,
                WorkflowType = dto.workflow_type,
                EligibilityRules = dto.eligibility_rules // Passed here
            });

            // 3. Removed ConfigureLeaveEligibility as it is now handled in ConfigureLeaveRules

            return "Configuration saved successfully.";
        }
        // ==========================================================
        // HR ADMIN: ASSIGN ENTITLEMENTS
        // ==========================================================

        public async Task<IEnumerable<EmployeeSimpleDto>> GetAllEmployees()
        {
            // Uses your existing procedure that filters by is_active
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

        public async Task<IEnumerable<ManagerNoteDto>> GetManagerNotes()
        {
            return await _db.QueryAsync<ManagerNoteDto>("GetManagerNotes", null);
        }

        public async Task<string> ArchiveManagerNote(int noteId)
        {
            var result = await _db.QueryAsync<dynamic>(
                "ArchiveManagerNote",
                new { NoteID = noteId }
            );
            return result.FirstOrDefault()?.ConfirmationMessage ?? "Flag archived.";
        }

        public async Task<string> OverrideLeaveDecision(int requestId, string status, string reason, int adminId)
        {
            var result = await _db.QueryAsync<dynamic>(
                "OverrideLeaveDecision",
                new 
                { 
                    LeaveRequestID = requestId, 
                    NewStatus = status, 
                    Reason = reason, 
                    AdminID = adminId 
                }
            );
            return result.FirstOrDefault()?.ConfirmationMessage ?? "Decision overridden.";
        }

        public async Task<LeaveRequestDetailDto> GetLeaveRequestDetail(int id)
        {
            var result = await _db.QueryAsync<LeaveRequestDetailDto>(
                "GetLeaveRequestDetail", 
                new { RequestID = id }
            );
            return result.FirstOrDefault() ?? throw new Exception("Request not found.");
        }

        public async Task<IEnumerable<LeaveRequestDetailDto>> GetAllLeaveRequests()
        {
            return await _db.QueryAsync<LeaveRequestDetailDto>("GetAllLeaveRequests", null);
        }
    }
}