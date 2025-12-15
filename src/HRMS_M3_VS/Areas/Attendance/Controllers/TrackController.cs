using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Areas.Attendance.Services;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims; // <--- 1. REQUIRED: To read User ID
using Microsoft.AspNetCore.Authorization; // <--- 2. REQUIRED: To force login

namespace HRMS_M3_VS.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    [Authorize] // <--- 3. CRITICAL: Ensures only logged-in users can open this page
    public class TrackController : Controller
    {
        private readonly TrackingService _track;

        // REMOVED: private const int CurrentUser = 2; 

        public TrackController(TrackingService track)
        {
            _track = track;
        }

        // ---------------------------------------------------------
        // 4. THE FIX: Dynamic Property to get the Real ID
        // ---------------------------------------------------------
        private int CurrentUserId
        {
            get
            {
                var idClaim = User.FindFirst(ClaimTypes.NameIdentifier);
                // If claim is missing (rare if [Authorize] is used), return 0 to prevent crash
                return idClaim != null ? int.Parse(idClaim.Value) : 0;
            }
        }

        // 1. View History
        public async Task<IActionResult> Index()
        {
            // USE CurrentUserId instead of CurrentUser
            var logs = await _track.GetMyAttendance(CurrentUserId);
            return View(logs);
        }

        // 2. Record Attendance (GET)
        public async Task<IActionResult> Record()
        {
            // Get assigned shifts for the dropdown
            ViewBag.Shifts = await _track.GetMyShifts(CurrentUserId);

            // Pass the REAL ID to the view
            return View(new RecordAttendanceDto { employee_id = CurrentUserId });
        }

        // 2. Record Attendance (POST)
        [HttpPost]
        public async Task<IActionResult> Record(RecordAttendanceDto dto)
        {
            // SECURITY: Overwrite the ID with the real logged-in ID
            // (Prevents hacking by changing hidden fields)
            dto.employee_id = CurrentUserId;

            if (!ModelState.IsValid)
            {
                ViewBag.Shifts = await _track.GetMyShifts(CurrentUserId);
                return View(dto);
            }

            string message = await _track.RecordAttendance(dto);
            TempData["Success"] = message ?? "Attendance Recorded.";
            return RedirectToAction("Index");
        }

        // --- CORRECTION METHODS ---

        // 1. GET: Show the form
        public IActionResult Correction()
        {
            return View(new CorrectionRequestDto
            {
                employee_id = CurrentUserId, // Use Real ID
                date = DateTime.Today.AddDays(-1)
            });
        }

        // 2. POST: Submit the data
        [HttpPost]
        public async Task<IActionResult> Correction(CorrectionRequestDto dto)
        {
            // SECURITY: Overwrite ID
            dto.employee_id = CurrentUserId;

            if (!ModelState.IsValid)
                return View(dto);

            // Call the service
            string message = await _track.SubmitCorrection(dto);

            // Handle Errors
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