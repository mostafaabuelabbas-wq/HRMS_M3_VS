using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    // ✅ NEW: Leave History with Attachment Count
    public class LeaveHistoryWithAttachmentsDto
    {
        public int request_id { get; set; }
        public string leave_type { get; set; } = string.Empty;
        public string justification { get; set; } = string.Empty;
        public int duration { get; set; }
        public string status { get; set; } = string.Empty;
        public DateTime? approval_timing { get; set; }
        public int attachment_count { get; set; }
    }
}
