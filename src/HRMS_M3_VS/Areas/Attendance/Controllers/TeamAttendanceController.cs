using HRMS_M3_VS.Areas.Employee.Services; // Or .Attendance.Services depending on where you put the service
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims; // <--- REQUIRED for getting the login ID

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

        // -----------------------------------------------------------
        // THE FIX: Get the Real ID from the Cookie
        // -----------------------------------------------------------
        private int CurrentManagerId
        {
            get
            {
                var idClaim = User.FindFirst(ClaimTypes.NameIdentifier);
                // If logged in, return ID. If not, return 0 (which returns empty list)
                return idClaim != null ? int.Parse(idClaim.Value) : 0;
            }
        }

        public async Task<IActionResult> Index(DateTime? start, DateTime? end)
        {
            var s = start ?? DateTime.Today.AddDays(-7);
            var e = end ?? DateTime.Today;

            ViewBag.Start = s;
            ViewBag.End = e;

            // USE "CurrentManagerId" NOT "6"
            var logs = await _service.GetTeamAttendance(CurrentManagerId, s, e);
            return View(logs);
        }
    }
}