using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Attendance.Models
{
    public class AssignToEmployeeDto
    {
        [Required]
        public int employee_id { get; set; }

        [Required]
        public int shift_id { get; set; }

        [Required]
        public DateTime start_date { get; set; } = DateTime.Today;

        [Required]
        public DateTime end_date { get; set; } = DateTime.Today.AddMonths(1);
    }

    // Class to hold data for the Employee Dropdown
    public class EmployeeSelectDto
    {
        public int employee_id { get; set; }
        public string full_name { get; set; }
    }
}