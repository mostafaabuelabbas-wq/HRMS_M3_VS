using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class AssignToDepartmentDto
    {
        [Required]
        public int department_id { get; set; }

        [Required]
        public int shift_id { get; set; }

        [Required]
        public DateTime start_date { get; set; } = DateTime.Today;

        [Required]
        public DateTime end_date { get; set; } = DateTime.Today.AddMonths(1);
    }

    // Class to hold data for the Department Dropdown
    public class DepartmentSelectDto
    {
        public int department_id { get; set; }
        public string department_name { get; set; }
    }
}