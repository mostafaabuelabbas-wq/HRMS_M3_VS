namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class LeaveHistoryDto
    {
        // Matches LeaveRequest column 'request_id'
        public int request_id { get; set; }

        // Matches [Leave] column 'leave_type'
        public string leave_type { get; set; } = string.Empty;

        // Matches LeaveRequest column 'justification'
        public string justification { get; set; } = string.Empty;

        // Matches LeaveRequest column 'duration'
        public int duration { get; set; }

        // Matches LeaveRequest column 'status'
        public string status { get; set; } = string.Empty;

        // Matches LeaveRequest column 'approval_timing'
        public DateTime? approval_timing { get; set; }
    }
}