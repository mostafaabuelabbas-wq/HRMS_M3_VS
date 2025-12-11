using Microsoft.AspNetCore.Mvc;
using HRMS_M3_VS.Areas.Employee.Services;

namespace HRMS_M3_VS.Areas.Employee.Controllers
{
    [Area("Employee")]
    public class ManagerController : Controller
    {
        private readonly EmployeeService _service;

        public ManagerController(EmployeeService service)
        {
            _service = service;
        }

        public async Task<IActionResult> Index()
        {
            // Temporary until authentication added
            int managerId = 1;

            var team = await _service.GetTeamByManagerAsync(managerId);

            return View(team);
        }
    }
}
