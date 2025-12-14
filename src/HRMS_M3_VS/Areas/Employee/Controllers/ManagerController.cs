using Microsoft.AspNetCore.Mvc;
using HRMS_M3_VS.Areas.Employee.Services;
using System.Security.Claims; // Required for User.FindFirstValue
using Microsoft.AspNetCore.Authorization;

namespace HRMS_M3_VS.Areas.Employee.Controllers
{
    [Area("Employee")]
    public class ManagerController : Controller
    {
        // Keep using EmployeeService as you had before
        private readonly EmployeeService _service;

        public ManagerController(EmployeeService service)
        {
            _service = service;
        }

        // -----------------------------------------------------------
        // THE FIX: Dynamic ID Helper
        // -----------------------------------------------------------
        private int CurrentManagerId
        {
            get
            {
                var idClaim = User.FindFirst(ClaimTypes.NameIdentifier);
                // Return the ID if logged in, otherwise 0
                return idClaim != null ? int.Parse(idClaim.Value) : 0;
            }
        }

        public async Task<IActionResult> Index()
        {
            // THE FIX: Use CurrentManagerId instead of 6
            var team = await _service.GetTeamByManagerAsync(CurrentManagerId);

            return View(team);
        }
    }
}