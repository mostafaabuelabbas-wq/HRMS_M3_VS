using HRMS_M3_VS.Areas.Employee.Services;
using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Attendance.Controllers // Changed namespace
{
    [Area("Attendance")] // Changed Area
    public class TeamAttendanceController : Controller
    {
        private readonly TeamAttendanceService _service;

        // MOCK ID: Assuming ID 1 is the Manager. 
        // IMPORTANT: Ensure Employee #1 is set as 'manager_id' for other employees in your DB.
        private const int CurrentUser = 1;

        public TeamAttendanceController(TeamAttendanceService service)
        {
            _service = service;
        }

        public async Task<IActionResult> Index(DateTime? start, DateTime? end)
        {
            // Default to showing the last 7 days if no date selected
            var s = start ?? DateTime.Today.AddDays(-7);
            var e = end ?? DateTime.Today;

            ViewBag.Start = s;
            ViewBag.End = e;

            var logs = await _service.GetTeamAttendance(CurrentUser, s, e);
            return View(logs);
        }
    }
}