using HRMS_M3_VS.Areas.Leave.Services;
using HRMS_M3_VS.Areas.Leave.Models;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization; // ✅ Added for security

namespace HRMS_M3_VS.Areas.Leave.Controllers
{
    [Area("Leave")]
    public class LeaveController : Controller
    {
        private readonly LeaveService _leaveService;

        public LeaveController(LeaveService leaveService)
        {
            _leaveService = leaveService;
        }

        // ==========================================================
        // MANAGER ACTIONS (Dashboard) - SECURED 🔒
        // ==========================================================

        // GET: Leave/Leave/Index
        [Authorize(Roles = "Manager")] // ✅ Only Managers can see this
        public async Task<IActionResult> Index()
        {
            int managerId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");

            try
            {
                var requests = await _leaveService.GetPendingLeaveRequests(managerId);
                return View(requests);
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error loading requests: " + ex.Message;
                return View(new List<PendingLeaveRequestDto>());
            }
        }

        // POST: Leave/Leave/Approve
        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "Manager")] // ✅ Only Managers can approve
        public async Task<IActionResult> Approve(int id)
        {
            int managerId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");

            try
            {
                var message = await _leaveService.ApproveLeaveRequest(id, managerId);
                TempData["Success"] = message;
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error approving request: " + ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        // POST: Leave/Leave/Reject
        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "Manager")] // ✅ Only Managers can reject
        public async Task<IActionResult> Reject(int id, string reason)
        {
            int managerId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");

            try
            {
                var message = await _leaveService.RejectLeaveRequest(id, managerId, reason);
                TempData["Success"] = message;
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error rejecting request: " + ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        // POST: Leave/Leave/Flag
        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "Manager")] // ✅ Only Managers can flag
        public async Task<IActionResult> Flag(int employeeId, string reason)
        {
            int managerId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");

            try
            {
                var message = await _leaveService.FlagIrregularLeave(employeeId, managerId, reason);
                TempData["Success"] = message;
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error flagging employee: " + ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        // ==========================================================
        // EMPLOYEE ACTIONS (Submit Leave & History) - OPEN TO ALL
        // ==========================================================

        // GET: Leave/Leave/MyLeave
        public async Task<IActionResult> MyLeave()
        {
            int employeeId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");

            var model = new EmployeeLeaveViewModel();

            try
            {
                model.Balances = await _leaveService.GetEmployeeBalance(employeeId);
                model.History = await _leaveService.GetEmployeeHistory(employeeId);
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error loading data: " + ex.Message;
            }

            return View(model);
        }

        // GET: Leave/Leave/Create
        public async Task<IActionResult> Create()
        {
            try
            {
                var types = await _leaveService.GetLeaveTypesForDropdown();
                ViewBag.LeaveTypes = types;
                return View(new LeaveApplyDto());
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Could not load leave types: " + ex.Message;
                return RedirectToAction("MyLeave");
            }
        }

        // POST: Leave/Leave/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(LeaveApplyDto model)
        {
            if (!ModelState.IsValid)
            {
                var types = await _leaveService.GetLeaveTypesForDropdown();
                ViewBag.LeaveTypes = types;
                return View(model);
            }

            int employeeId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");

            try
            {
                await _leaveService.SubmitLeaveRequest(employeeId, model);
                TempData["Success"] = "Leave request submitted successfully!";
                return RedirectToAction(nameof(MyLeave));
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error: " + ex.Message;
                var types = await _leaveService.GetLeaveTypesForDropdown();
                ViewBag.LeaveTypes = types;
                return View(model);
            }
        }

        // ==========================================================
        // HR ADMIN ACTIONS - SECURED 🔒
        // ==========================================================

        // GET: Leave/Leave/ManageTypes
        [Authorize(Roles = "HRAdmin")] // ✅ Optional: Secure HR Area too
        public async Task<IActionResult> ManageTypes()
        {
            try 
            {
                var types = await _leaveService.GetLeaveConfigurations();
                // Map config DTO to simpler list if needed, or use the Config View
                // For now, returning the simple view to match previous state
                return View(types);
            }
            catch
            {
                return View(new List<LeaveConfigDto>());
            }
        }

        // POST: Leave/Leave/CreateType
        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "HRAdmin")]
        public async Task<IActionResult> CreateType(LeaveConfigDto model)
        {
            if (!ModelState.IsValid) return RedirectToAction(nameof(ManageTypes));

            try
            {
                await _leaveService.SaveLeaveConfiguration(model);
                TempData["Success"] = "Configuration saved.";
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(ManageTypes));
        }
    }
}