using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class ShiftCycleDto
    {
        // Properties must match SQL Column names exactly
        public int cycle_id { get; set; }

        public string cycle_name { get; set; } = string.Empty;

        public string description { get; set; } = string.Empty;
    }
}