using HRMS_M3_VS.Areas.Employee.Services;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims; // <--- Required to read the User ID

namespace HRMS_M3_VS.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    public class TeamAttendanceController : Controller
    {
        private readonly TeamAttendanceService _service;

        public TeamAttendanceController(TeamAttendanceService service)
        {
            _service = service;
        }

        // -------------------------------------------------------------
        // HELPER: Get the Real Logged-In User ID
        // -------------------------------------------------------------
        private int CurrentManagerId
        {
            get
            {
                // Finds the "NameIdentifier" claim (which holds the ID)
                var idClaim = User.FindFirst(ClaimTypes.NameIdentifier);

                // If found, parse it to int. If not found (not logged in), return 0.
                return idClaim != null ? int.Parse(idClaim.Value) : 0;
            }
        }

        public async Task<IActionResult> Index(DateTime? start, DateTime? end)
        {
            // Default to showing the last 7 days if no date selected
            var s = start ?? DateTime.Today.AddDays(-7);
            var e = end ?? DateTime.Today;

            ViewBag.Start = s;
            ViewBag.End = e;

            // Pass the Real Logged-in Manager ID instead of a Mock ID
            var logs = await _service.GetTeamAttendance(CurrentManagerId, s, e);

            return View(logs);
        }
    }
}