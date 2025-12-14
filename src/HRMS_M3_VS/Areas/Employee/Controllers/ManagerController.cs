using Microsoft.AspNetCore.Mvc;
using HRMS_M3_VS.Areas.Employee.Services;
using System.Security.Claims; // <--- NEEDED FOR User.FindFirstValue
using Microsoft.AspNetCore.Authorization; // <--- NEEDED FOR Security

namespace HRMS_M3_VS.Areas.Employee.Controllers
{
    [Area("Employee")]
    [Authorize(Roles = "Manager")] // <--- SECURITY: Only Managers allowed
    public class ManagerController : Controller
    {
        private readonly EmployeeService _service;

        public ManagerController(EmployeeService service)
        {
            _service = service;
        }

        public async Task<IActionResult> Index()
        {
            int managerId = 6; // <-- USE THE REAL ID YOU FOUND

            var team = await _service.GetTeamByManagerAsync(managerId);
            return View(team);
        }
    }
}