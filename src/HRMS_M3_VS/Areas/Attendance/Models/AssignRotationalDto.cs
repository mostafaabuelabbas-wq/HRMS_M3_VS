using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class AssignRotationalDto
    {
        [Required]
        public int employee_id { get; set; }

        [Required]
        public int cycle_id { get; set; }

        [Required]
        public DateTime start_date { get; set; } = DateTime.Today;

        [Required]
        public DateTime end_date { get; set; } = DateTime.Today.AddMonths(1);
    }
}