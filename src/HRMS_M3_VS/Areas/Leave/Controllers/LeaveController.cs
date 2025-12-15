using HRMS_M3_VS.Areas.Leave.Services;
using HRMS_M3_VS.Areas.Leave.Models;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;

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
        // 1. MANAGER ACTIONS (Dashboard) - SECURED 🔒
        // ==========================================================

        [Authorize(Roles = "Manager")]
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
                TempData["Error"] = "Error: " + ex.Message;
                return View(new List<PendingLeaveRequestDto>());
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "Manager")]
        public async Task<IActionResult> Approve(int id)
        {
            int managerId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");
            try
            {
                var message = await _leaveService.ApproveLeaveRequest(id, managerId);
                TempData["Success"] = message;
            }
            catch (Exception ex) { TempData["Error"] = ex.Message; }
            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "Manager")]
        public async Task<IActionResult> Reject(int id, string reason)
        {
            int managerId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");
            try
            {
                var message = await _leaveService.RejectLeaveRequest(id, managerId, reason);
                TempData["Success"] = message;
            }
            catch (Exception ex) { TempData["Error"] = ex.Message; }
            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "Manager")]
        public async Task<IActionResult> Flag(int employeeId, string reason)
        {
            int managerId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");
            try
            {
                var message = await _leaveService.FlagIrregularLeave(employeeId, managerId, reason);
                TempData["Success"] = message;
            }
            catch (Exception ex) { TempData["Error"] = ex.Message; }
            return RedirectToAction(nameof(Index));
        }

        // ==========================================================
        // 2. EMPLOYEE ACTIONS (Submit Leave & History) - OPEN TO ALL
        // ==========================================================

        public async Task<IActionResult> MyLeave()
        {
            int employeeId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");
            var model = new EmployeeLeaveViewModel();
            try
            {
                model.Balances = await _leaveService.GetEmployeeBalance(employeeId);
                model.History = await _leaveService.GetEmployeeHistory(employeeId);
            }
            catch (Exception ex) { TempData["Error"] = "Error: " + ex.Message; }
            return View(model);
        }

        public async Task<IActionResult> Create()
        {
            try
            {
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown();
                return View(new LeaveApplyDto());
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error: " + ex.Message;
                return RedirectToAction("MyLeave");
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(LeaveApplyDto model)
        {
            if (!ModelState.IsValid)
            {
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown();
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
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown();
                return View(model);
            }
        }

        // ==========================================================
        // 3. HR ADMIN ACTIONS (Configuration) - SECURED 🔒
        // ==========================================================

        // 1. Grid View (List all types)
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> ManageTypes()
        {
            try
            {
                var types = await _leaveService.GetLeaveConfigurations();
                return View(types);
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error: " + ex.Message;
                return View(new List<LeaveConfigDto>());
            }
        }

        // 2. Form View (Create or Edit)
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> EditType(string id)
        {
            if (string.IsNullOrEmpty(id))
            {
                // Create Mode
                return View(new LeaveConfigDto());
            }

            // Edit Mode: Find the existing item
            var list = await _leaveService.GetLeaveConfigurations();
            var item = list.FirstOrDefault(x => x.leave_type == id);

            if (item == null) return NotFound();

            return View(item);
        }

        // 3. Submit Action
        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> SaveType(LeaveConfigDto model)
        {
            if (!ModelState.IsValid) return View("EditType", model);

            try
            {
                await _leaveService.SaveLeaveConfiguration(model);
                TempData["Success"] = "Configuration saved successfully.";
                return RedirectToAction(nameof(ManageTypes));
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
                return View("EditType", model);
            }
        }
        // ==========================================================
        // HR ADMIN: ASSIGN ENTITLEMENTS
        // ==========================================================

        // GET: Leave/Leave/AssignEntitlement
        [Authorize(Roles = "HRAdmin")]
        public async Task<IActionResult> AssignEntitlement()
        {
            try
            {
                // 1. Load Employees for Dropdown
                ViewBag.Employees = await _leaveService.GetAllEmployees();
                
                // 2. Load Leave Types for Dropdown
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown();
                
                return View(new AssignEntitlementDto());
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error loading data: " + ex.Message;
                return RedirectToAction(nameof(ManageTypes));
            }
        }

        // POST: Leave/Leave/AssignEntitlement
        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "HRAdmin")]
        public async Task<IActionResult> AssignEntitlement(AssignEntitlementDto model)
        {
            if (!ModelState.IsValid)
            {
                // Reload dropdowns if validation fails
                ViewBag.Employees = await _leaveService.GetAllEmployees();
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown();
                return View(model);
            }

            try
            {
                var message = await _leaveService.AssignEntitlement(model);
                TempData["Success"] = message;
                
                // Redirect back to same page so you can add another one easily
                return RedirectToAction(nameof(AssignEntitlement));
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error: " + ex.Message;
                
                // Reload dropdowns on error
                ViewBag.Employees = await _leaveService.GetAllEmployees();
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown();
                return View(model);
            }
        }
    }
}