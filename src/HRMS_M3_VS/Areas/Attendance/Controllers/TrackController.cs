using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Areas.Attendance.Services;
using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    public class TrackController : Controller
    {
        private readonly TrackingService _track;
        private const int CurrentUser = 2; // MOCK ID

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
        // --- ADD THESE METHODS ---

        // 1. GET: Show the form
        public IActionResult Correction()
        {
            return View(new CorrectionRequestDto
            {
                employee_id = CurrentUser, // (Remember, this is ID 1 for now)
                date = DateTime.Today.AddDays(-1) // Default to yesterday
            });
        }

        // 2. POST: Submit the data
        [HttpPost]
        public async Task<IActionResult> Correction(CorrectionRequestDto dto)
        {
            if (!ModelState.IsValid)
                return View(dto);

            // Call the service
            string message = await _track.SubmitCorrection(dto);

            // Handle Errors (Your SQL might return 'Invalid employee ID' or success message)
            if (!string.IsNullOrEmpty(message) && (message.StartsWith("Error") || message.Contains("Invalid")))
            {
                ViewBag.Error = message;
                return View(dto);
            }

            TempData["Success"] = message;
            return RedirectToAction("Index");
        }
    }
}