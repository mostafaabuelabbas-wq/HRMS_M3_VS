using Microsoft.AspNetCore.Mvc.Rendering;
using System.ComponentModel.DataAnnotations;

namespace HRMS_M3_VS.Areas.Employee.Models;

public class MissionCreateViewModel
{
    [Required]
    public int EmployeeId { get; set; }

    public int ManagerId { get; set; }

  
    // Keep the rest...
    public IEnumerable<SelectListItem>? Employees { get; set; }
    [Required]
    public string Destination { get; set; }
    public string Description { get; set; }
    [Required]
    public DateTime StartDate { get; set; }
    [Required]
    public DateTime EndDate { get; set; }
}