using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class LeaveConfigDto
    {
        public int leave_id { get; set; }

        [Required]
        [Display(Name = "Leave Type Name")]
        public string leave_type { get; set; } = string.Empty;

        [Display(Name = "Description")]
        public string leave_description { get; set; } = string.Empty; // Changed to match DB column

        [Display(Name = "Notice Period (Days)")]
        public int notice_period { get; set; }

        [Display(Name = "Max Duration (Days)")]
        public int max_duration { get; set; }

        [Display(Name = "Workflow Type")]
        public string workflow_type { get; set; } = "Standard";

        [Display(Name = "Eligibility (Employee Type)")]
        public string eligibility_rules { get; set; } = "All"; // Changed from EmployeeType to eligibility_rules
    }
}