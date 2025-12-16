using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class LeaveTypeDropdownDto
    {
        public int leave_id { get; set; }
        public string leave_type { get; set; } = string.Empty;
    }
}
