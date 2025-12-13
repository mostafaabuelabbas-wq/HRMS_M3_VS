using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Areas.Attendance.Services; // Ensure this using exists
using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    public class AttendanceManagerController : Controller
    {
        // Inject the NEW service
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
        public async Task<IActionResult> SyncLeaves()
        {
            // Now calling the correct service
            var leaves = await _adminService.GetLeavesForSync();
            return View(leaves);
        }

        // 3. SYNC LEAVES (POST)
        [HttpPost]
        public async Task<IActionResult> SyncLeaves(int id)
        {
            try
            {
                // Now calling the correct service
                string message = await _adminService.SyncLeave(id);
                TempData["Success"] = message;
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error: " + ex.Message;
            }
            return RedirectToAction("SyncLeaves");
        }
        // 1. GET: Show the Simulation Form
        public async Task<IActionResult> OfflineSync()
        {
            // Load employees for the dropdown so you don't have to guess IDs
            ViewBag.Employees = await _adminService.GetAllEmployees();
            return View(new OfflineSyncDto());
        }

        // 2. POST: Submit the data (Simulating the Device connecting)
        [HttpPost]
        public async Task<IActionResult> OfflineSync(OfflineSyncDto dto)
        {
            if (!ModelState.IsValid)
            {
                ViewBag.Employees = await _adminService.GetAllEmployees();
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

            // Redirect back to the same page to add more records
            return RedirectToAction("OfflineSync");
        }
        // GET: Show Breaches (Defaults to Today)
        public async Task<IActionResult> TimeRules(DateTime? date)
        {
            var targetDate = date ?? DateTime.Today;
            ViewBag.SelectedDate = targetDate;

            var breaches = await _adminService.GetBreaches(targetDate);
            return View(breaches);
        }
    }
}