using HRMS_M3_VS.Areas.Employee.Services;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace HRMS_M3_VS.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    [Microsoft.AspNetCore.Authorization.Authorize] // Require login broadly
    public class TeamAttendanceController : Controller
    {
        private readonly TeamAttendanceService _service;

        public TeamAttendanceController(TeamAttendanceService service)
        {
            _service = service;
        }

        private int CurrentManagerId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "0");

        // Updated Index to handle "viewAll"
        public async Task<IActionResult> Index(string filter = "today", bool viewAll = false, DateTime? start = null, DateTime? end = null)
        {
            DateTime s, e;

            // 1. Date Logic
            switch (filter.ToLower())
            {
                case "week":
                    s = DateTime.Today.AddDays(-6);
                    e = DateTime.Today;
                    break;
                case "month":
                    s = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1);
                    e = DateTime.Today;
                    break;
                case "custom":
                    s = start ?? DateTime.Today;
                    e = end ?? DateTime.Today;
                    break;
                case "today":
                default:
                    s = DateTime.Today;
                    e = DateTime.Today;
                    break;
            }

            // 2. Manager Logic (Who do we fetch?)
            int managerIdToFetch = CurrentManagerId;

            // SECURITY CHECK: Only Admins can use "View All"
            bool isAdmin = User.IsInRole("SystemAdmin") || User.IsInRole("HRAdmin");

            if (viewAll && isAdmin)
            {
                managerIdToFetch = 0; // 0 tells SQL to fetch everyone
            }

            ViewBag.Filter = filter;
            ViewBag.IsViewAll = (viewAll && isAdmin); // To toggle button state
            ViewBag.CanViewAll = isAdmin;             // To show/hide button
            ViewBag.Start = s;
            ViewBag.End = e;

            var logs = await _service.GetTeamAttendance(managerIdToFetch, s, e);
            return View(logs);
        }
        // --- VIEW SPECIFIC EMPLOYEE HISTORY ---
        public async Task<IActionResult> History(int id, string filter = "month", DateTime? start = null, DateTime? end = null)
        {
            DateTime s, e;

            // Standard Date Logic
            switch (filter.ToLower())
            {
                case "week":
                    s = DateTime.Today.AddDays(-6);
                    e = DateTime.Today;
                    break;
                case "month":
                    s = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1);
                    e = DateTime.Today;
                    break;
                case "year":
                    s = new DateTime(DateTime.Today.Year, 1, 1);
                    e = DateTime.Today;
                    break;
                case "custom":
                    s = start ?? DateTime.Today;
                    e = end ?? DateTime.Today;
                    break;
                default: // month
                    s = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1);
                    e = DateTime.Today;
                    break;
            }

            ViewBag.Filter = filter;
            ViewBag.Start = s;
            ViewBag.End = e;
            ViewBag.TargetEmployeeId = id; // Pass ID to view for pagination/filtering

            var logs = await _service.GetEmployeeHistory(id, s, e);

            // Grab name for the header (safely)
            ViewBag.EmployeeName = logs.FirstOrDefault()?.full_name ?? "Employee #" + id;

            return View(logs);
        }
    }
}