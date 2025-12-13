using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class ContractRenewViewModel
    {
        [Required]
        public int ContractId { get; set; }

        [Required]
        [Display(Name = "New End Date")]
        public DateTime NewEndDate { get; set; }

        [StringLength(500)]
        public string? Notes { get; set; }

        // For display
        public string? EmployeeName { get; set; }
        public string? CurrentType { get; set; }
        public DateTime? CurrentEndDate { get; set; }
    }
}