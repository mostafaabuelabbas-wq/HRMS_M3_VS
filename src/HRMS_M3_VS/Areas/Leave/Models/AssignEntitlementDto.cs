using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class AssignEntitlementDto
    {
        [Required]
        public int EmployeeId { get; set; }

        [Required]
        public int LeaveTypeId { get; set; }

        [Required]
        [Range(0, 365)]
        public decimal Entitlement { get; set; }
    }


    // Helper class for the employee dropdown
    public class EmployeeSimpleDto
    {
        public int employee_id { get; set; }
        public string full_name { get; set; } = string.Empty;
    }
}