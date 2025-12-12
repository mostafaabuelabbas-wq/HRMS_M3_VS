using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class RecordAttendanceDto
    {
        [Required]
        public int employee_id { get; set; }

        [Required]
        public int shift_id { get; set; }

        [Required]
        public TimeSpan entry_time { get; set; }

        [Required]
        public TimeSpan exit_time { get; set; }
    }
}