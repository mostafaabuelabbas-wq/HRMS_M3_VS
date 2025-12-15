using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class AssignEntitlementDto
    {
        [Required(ErrorMessage = "Please select an employee")]
        [Display(Name = "Employee")]
        public int EmployeeId { get; set; }

        [Required(ErrorMessage = "Please select a leave type")]
        [Display(Name = "Leave Type")]
        public int LeaveTypeId { get; set; }

        [Required]
        [Range(0, 365, ErrorMessage = "Days must be between 0 and 365")]
        [Display(Name = "Total Days Allowed")]
        public decimal Entitlement { get; set; }
    }

    // Helper class for the employee dropdown
    public class EmployeeSimpleDto
    {
        public int employee_id { get; set; }
        public string full_name { get; set; } = string.Empty;
    }
}