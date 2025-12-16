using System;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class OfflinePunchDto
    {
        public int EmployeeId { get; set; }
        public string Type { get; set; } // "ClockIn" or "ClockOut"
        public DateTime Timestamp { get; set; }
    }
}
