namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class ManagerNoteDto
    {
        public int NoteId { get; set; }
        public int EmployeeId { get; set; }
        public string EmployeeName { get; set; } = string.Empty;
        public int ManagerId { get; set; }
        public string ManagerName { get; set; } = string.Empty;
        public string NoteContent { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }
}
