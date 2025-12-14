using Microsoft.AspNetCore.Mvc.Rendering;
using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class ContractCreateViewModel
    {
        [Required]
        public int EmployeeId { get; set; }


        // List for the Dropdown
        public IEnumerable<SelectListItem>? Employees { get; set; }

        [Required]
        public string Type { get; set; } // FullTime, PartTime, etc.

        [Required]
        [DataType(DataType.Date)]
        public DateTime StartDate { get; set; }

        [Required]
        [DataType(DataType.Date)]
        public DateTime EndDate { get; set; }
    }
}