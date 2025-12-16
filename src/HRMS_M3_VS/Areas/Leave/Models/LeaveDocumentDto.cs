using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    // ✅ NEW: DTO for Leave Documents/Attachments
    public class LeaveDocumentDto
    {
        public int DocumentId { get; set; }
        public int LeaveRequestId { get; set; }
        public string FilePath { get; set; } = string.Empty;
        public DateTime UploadedAt { get; set; }

        // Helper property to get just the filename
        public string FileName => Path.GetFileName(FilePath);
    }

}
