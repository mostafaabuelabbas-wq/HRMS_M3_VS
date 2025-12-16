using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Areas.Attendance.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace HRMS_M3_VS.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    public class AttendanceManagerController : Controller
    {
        private readonly AttendanceAdminService _adminService;

        public AttendanceManagerController(AttendanceAdminService adminService)
        {
            _adminService = adminService;
        }

        // 1. DASHBOARD
        public IActionResult Index()
        {
            return View();
        }

        // 2. SYNC LEAVES (GET)
        [Authorize(Roles = "SystemAdmin")] // STRICT: Only SystemAdmin
        public async Task<IActionResult> SyncLeaves()
        {
            var leaves = await _adminService.GetLeavesForSync();
            return View(leaves);
        }

        // 3. SYNC LEAVES (POST)
        [HttpPost]
        [Authorize(Roles = "SystemAdmin")] // STRICT: Only SystemAdmin
        public async Task<IActionResult> SyncLeaves(int id)
        {
            try
            {
                // Double Safety Check (Backend)
                if (!User.IsInRole("SystemAdmin"))
                {
                    return Forbid();
                }

                string message = await _adminService.SyncLeave(id);
                
                // Note: The SP 'SyncLeaveToAttendance' should strictly handle 'Approved' check.
                // If it doesn't, we trust the service call output or add checks here if visible.
                
                if (message.Contains("Error")) // Assuming service returns friendly errors
                {
                    TempData["Error"] = message;
                }
                else
                {
                    TempData["Success"] = message;
                }
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error: " + ex.Message;
            }
            return RedirectToAction("SyncLeaves");
        }

        // 1. GET: Show the Simulation Form
        [Authorize(Roles = "SystemAdmin,Manager")]
        public async Task<IActionResult> OfflineSync()
        {
            int? managerId = null;

            // If NOT SystemAdmin (i.e., is just a Manager), force filter
            if (!User.IsInRole("SystemAdmin"))
            {
                var claimId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
                if (int.TryParse(claimId, out int mid))
                {
                    managerId = mid;
                }
            }

            // Load employees (filtered if managerId is present)
            ViewBag.Employees = await _adminService.GetAllEmployees(managerId);
            return View(new OfflineSyncDto());
        }

        // 2. POST: Submit the data (Simulating the Device connecting)
        [HttpPost]
        [Authorize(Roles = "SystemAdmin,Manager")]
        public async Task<IActionResult> OfflineSync(OfflineSyncDto dto)
        {
            // Re-load dropdown on error (with same filter logic)
            if (!ModelState.IsValid)
            {
                int? managerId = null;
                if (!User.IsInRole("SystemAdmin"))
                {
                    var claimId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
                    if (int.TryParse(claimId, out int mid)) managerId = mid;
                }
                
                ViewBag.Employees = await _adminService.GetAllEmployees(managerId);
                return View(dto);
            }

            try
            {
                string message = await _adminService.SyncOfflineRecord(dto);
                TempData["Success"] = message;
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Sync Failed: " + ex.Message;
            }

            return RedirectToAction("OfflineSync");
        }

        // GET: Show Breaches with Filters
        [Authorize(Roles = "SystemAdmin,HRAdmin,Manager")]
        public async Task<IActionResult> TimeRules(string filter = "today")
        {
            DateTime startDate = DateTime.Today;
            DateTime endDate = DateTime.Today;

            switch (filter.ToLower())
            {
                case "week":
                    // Start of week (assuming Sunday start, or Monday depending on locale)
                    // Let's use Monday as start of work week
                    int diff = (7 + (DateTime.Today.DayOfWeek - DayOfWeek.Monday)) % 7;
                    startDate = DateTime.Today.AddDays(-1 * diff);
                    endDate = DateTime.Today;
                    break;
                case "month":
                    startDate = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1);
                    endDate = DateTime.Today;
                    break;
                case "year":
                    startDate = new DateTime(DateTime.Today.Year, 1, 1);
                    endDate = DateTime.Today;
                    break;
                case "today":
                default:
                    startDate = DateTime.Today;
                    endDate = DateTime.Today;
                    break;
            }

            ViewBag.Filter = filter;
            ViewBag.StartDate = startDate;
            ViewBag.EndDate = endDate;

            var breaches = await _adminService.GetAttendanceAnalysis(startDate, endDate);
            return View(breaches);
        }
    }
}