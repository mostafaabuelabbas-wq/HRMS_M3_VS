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

        // 2. Record Attendance View (GET) - Now just shows Buttons
        public async Task<IActionResult> Record()
        {
            // View now just needs the EmployeeID to confirm identity if needed
            // No drop downs needed for Simple Clock In
            return View(new RecordAttendanceDto { employee_id = CurrentUserId });
        }

        // 3. CLOCK IN ACTION
        [HttpPost]
        public async Task<IActionResult> ClockIn()
        {
            string msg = await _track.RecordPunch(CurrentUserId, DateTime.Now, "ClockIn");
            
            if (msg.Contains("Error") || msg.Contains("Duplicate")) // Check for DB error messages
                 TempData["Error"] = msg;
            else
                 TempData["Success"] = "Clocked In Successfully at " + DateTime.Now.ToString("t");

            return RedirectToAction("Index");
        }

        // 4. CLOCK OUT ACTION
        [HttpPost]
        public async Task<IActionResult> ClockOut()
        {
            string msg = await _track.RecordPunch(CurrentUserId, DateTime.Now, "ClockOut");
            
            if (msg.Contains("Error")) 
                 TempData["Error"] = msg;
            else
                 TempData["Success"] = "Clocked Out Successfully at " + DateTime.Now.ToString("t");

            return RedirectToAction("Index");
        }

        // 5. OFFLINE SYNC (API)
        [HttpPost]
        [Route("Attendance/Track/SyncOffline")]
        public async Task<IActionResult> SyncOffline([FromBody] List<OfflinePunchDto> punches)
        {
            if (punches == null || !punches.Any())
                return BadRequest("No data received");

            int successCount = 0;
            foreach (var p in punches)
            {
                // Ensure ID match for security (unless Admin, but this is for self-service)
                int empId = CurrentUserId; 
                if (empId == 0) return Unauthorized();

                // Call existing service
                await _track.RecordPunch(empId, p.Timestamp, p.Type);
                successCount++;
            }

            return Ok(new { message = $"Synced {successCount} records successfully." });
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