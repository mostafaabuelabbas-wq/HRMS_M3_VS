using HRMS_M3_VS.Services;
using HRMS_M3_VS.Areas.Leave.Models;
using Dapper; 

namespace HRMS_M3_VS.Areas.Leave.Services
{
    public class LeaveService
    {
        private readonly DbService _db;

        public LeaveService(DbService db)
        {
            _db = db;
        }

        // ==========================================================
        // MANAGER FEATURES
        // ==========================================================

        // Manager: View pending leave requests
        public async Task<IEnumerable<PendingLeaveRequestDto>> GetPendingLeaveRequests(int managerId)
        {
            return await _db.QueryAsync<PendingLeaveRequestDto>(
                "GetPendingLeaveRequests",
                new { ManagerID = managerId }
            );
        }

        // Manager: Approve leave request
        public async Task<string> ApproveLeaveRequest(int leaveRequestId, int managerId)
        {
            await _db.QueryAsync<dynamic>(
                "ApproveLeaveRequest",
                new
                {
                    LeaveRequestID = leaveRequestId,
                    ApproverID = managerId,
                    Status = "Approved"
                }
            );
            return "Leave request approved successfully.";
        }

        // Manager: Reject leave request
        public async Task<string> RejectLeaveRequest(int leaveRequestId, int managerId, string reason)
        {
            await _db.QueryAsync<dynamic>(
                "RejectLeaveRequest",
                new
                {
                    LeaveRequestID = leaveRequestId,
                    ManagerID = managerId,
                    Reason = reason
                }
            );
            return "Leave request rejected successfully.";
        }

        // ==========================================================
        // EMPLOYEE FEATURES
        // ==========================================================

        // Helper: Get list of leave types for the dropdown
        public async Task<IEnumerable<dynamic>> GetLeaveTypes()
        {
            // Direct query since no specific SP was mandated for this list in the PDF
            return await _db.QueryAsync<dynamic>("SELECT leave_id, leave_type FROM [Leave]", new { });
        }

        // Employee: Submit a new request
        public async Task SubmitLeaveRequest(int employeeId, CreateLeaveRequestDto dto)
        {
            // 1. Call the Stored Procedure
            // It returns { NewRequestId, ConfirmationMessage }
            var result = await _db.QueryAsync<dynamic>(
                "SubmitLeaveRequest",
                new
                {
                    EmployeeID = employeeId,
                    LeaveTypeID = dto.LeaveTypeId,
                    StartDate = dto.StartDate,
                    EndDate = dto.EndDate,
                    Reason = dto.Justification
                }
            );

            var row = result.FirstOrDefault();

            // 2. Check for Logic Errors (e.g., "Insufficient balance")
            if (row == null || row.NewRequestId == 0)
            {
                string msg = row?.ConfirmationMessage ?? "Submission failed. Please check your inputs.";
                throw new Exception(msg);
            }

            int newRequestId = (int)row.NewRequestId;

            // 3. Handle File Upload (Attachment)
            if (dto.Attachment != null && dto.Attachment.Length > 0)
            {
                // Create unique filename
                var fileName = $"{Guid.NewGuid()}_{Path.GetFileName(dto.Attachment.FileName)}";
                
                // Define path: wwwroot/uploads/leaves
                var uploadDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "leaves");
                var filePath = Path.Combine(uploadDir, fileName);

                // Create directory if it doesn't exist
                if (!Directory.Exists(uploadDir))
                {
                    Directory.CreateDirectory(uploadDir);
                }

                // Save file to server
                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await dto.Attachment.CopyToAsync(stream);
                }

                // 4. Save file record to Database
                // Using the specific SP for documents
                await _db.QueryAsync<dynamic>(
                    "InsertLeaveDocument", 
                    new 
                    { 
                        LeaveRequestId = newRequestId, 
                        FilePath = "/uploads/leaves/" + fileName 
                    }
                );
            }
        }
    }
}