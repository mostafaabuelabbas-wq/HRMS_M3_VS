using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class ContractCreateViewModel
    {
        [Required] public int EmployeeId { get; set; }
        [Required] public string Type { get; set; } = "";
        [Required] public DateTime StartDate { get; set; }
        [Required] public DateTime EndDate { get; set; }
        public string? CurrentState { get; set; }
        public string? Notes { get; set; } // optional
    }
}
