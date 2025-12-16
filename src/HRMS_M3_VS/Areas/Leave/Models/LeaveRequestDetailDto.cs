using System;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class LeaveRequestDetailDto
    {
        public int request_id { get; set; }
        public int employee_id { get; set; }
        public string employee_name { get; set; }
        public string leave_type { get; set; }
        public string justification { get; set; }
        public int duration { get; set; }
        public string status { get; set; }
        public DateTime? approval_timing { get; set; }
    }
}
