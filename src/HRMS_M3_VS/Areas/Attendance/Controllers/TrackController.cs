using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Areas.Attendance.Services;
using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    public class TrackController : Controller
    {
        private readonly TrackingService _track;
        private const int CurrentUser = 1; // MOCK ID

        public TrackController(TrackingService track)
        {
            _track = track;
        }

        // 1. View History
        public async Task<IActionResult> Index()
        {
            var logs = await _track.GetMyAttendance(CurrentUser);
            return View(logs);
        }

        // 2. Record Attendance (GET)
        public async Task<IActionResult> Record()
        {
            // Get assigned shifts for the dropdown
            ViewBag.Shifts = await _track.GetMyShifts(CurrentUser);
            return View(new RecordAttendanceDto { employee_id = CurrentUser });
        }

        // 2. Record Attendance (POST)
        [HttpPost]
        public async Task<IActionResult> Record(RecordAttendanceDto dto)
        {
            if (!ModelState.IsValid)
            {
                ViewBag.Shifts = await _track.GetMyShifts(CurrentUser);
                return View(dto);
            }

            string message = await _track.RecordAttendance(dto);
            TempData["Success"] = message ?? "Attendance Recorded.";
            return RedirectToAction("Index");
        }
    }
}