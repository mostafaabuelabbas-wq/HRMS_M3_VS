using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class ContractRenewViewModel
    {
        [Required] public int ContractId { get; set; }
        [Required] public DateTime NewEndDate { get; set; }
        public string? Notes { get; set; }
    }
}
