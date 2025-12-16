namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class PendingLeaveRequestDto
    {
        public int RequestId { get; set; }
        public int EmployeeId { get; set; }
        public string EmployeeName { get; set; } = string.Empty;
        public string LeaveType { get; set; } = string.Empty;
        public string Justification { get; set; } = string.Empty;
        public int Duration { get; set; }
        public string Status { get; set; } = string.Empty;
        
        // Needed for the Card UI
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public string AttachmentPath { get; set; } = string.Empty;
    }
}