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
            // 1. Get the Logged-in User's ID
            var userIdString = User.FindFirstValue(ClaimTypes.NameIdentifier);

            // Safety check: If for some reason the ID is missing, send to login
            if (string.IsNullOrEmpty(userIdString))
            {
                return RedirectToAction("Login", "Account", new { area = "" });
            }

            int managerId = int.Parse(userIdString);

            // 2. Fetch the team for THIS manager
            var team = await _service.GetTeamByManagerAsync(managerId);

            return View(team);
        }
    }
}