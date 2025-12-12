using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class AssignCustomDto
    {
        [Required]
        public int employee_id { get; set; }

        [Required]
        public string shift_name { get; set; } = "Custom Shift";

        [Required]
        public string shift_type { get; set; } = "Custom";

        [Required]
        public TimeSpan start_time { get; set; }

        [Required]
        public TimeSpan end_time { get; set; }

        [Required]
        public DateTime start_date { get; set; } = DateTime.Today;

        [Required]
        public DateTime end_date { get; set; } = DateTime.Today;
    }
}