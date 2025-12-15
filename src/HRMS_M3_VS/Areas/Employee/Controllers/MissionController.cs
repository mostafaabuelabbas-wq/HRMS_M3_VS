using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using HRMS_M3_VS.Areas.Employee.Services;
using HRMS_M3_VS.Areas.Employee.Models;
using System.Security.Claims;

namespace HRMS_M3_VS.Areas.Employee.Controllers
{
    [Area("Employee")]
    [Authorize] // Everyone logged in can access at least the index
    public class MissionController : Controller
    {
        private readonly MissionService _service;

        public MissionController(MissionService service)
        {
            _service = service;
        }

        // GET: List of Missions
        public async Task<IActionResult> Index()
        {
            int userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier));

            // Determine Role for SQL filtering
            string role = "Employee";
            if (User.IsInRole("HRAdmin")) role = "HRAdmin";
            else if (User.IsInRole("Manager")) role = "Manager";

            var list = await _service.GetMissionsAsync(userId, role);
            return View(list);
        }

        // GET: Create Page (HR ONLY)
        [Authorize(Roles = "HRAdmin")]
        public async Task<IActionResult> Create()
        {
            var vm = new MissionCreateViewModel
            {
                StartDate = DateTime.Today,
                EndDate = DateTime.Today.AddDays(3),
                Employees = await _service.GetUserListAsync()
                // REMOVED: Managers = ...
            };
            return View(vm);
        }

        [HttpPost]
        [Authorize(Roles = "HRAdmin")]
        public async Task<IActionResult> Create(MissionCreateViewModel vm)
        {
            if (!ModelState.IsValid)
            {
                vm.Employees = await _service.GetUserListAsync();
                // REMOVED: vm.Managers = ...
                return View(vm);
            }

            await _service.AssignMissionAsync(vm);
            return RedirectToAction(nameof(Index));
        }

        // POST: Approve/Reject (Manager ONLY)
        [HttpPost]
        [Authorize(Roles = "Manager")]
        public async Task<IActionResult> UpdateStatus(int id, string status)
        {
            await _service.UpdateStatusAsync(id, status);
            return RedirectToAction(nameof(Index));
        }
    }
}