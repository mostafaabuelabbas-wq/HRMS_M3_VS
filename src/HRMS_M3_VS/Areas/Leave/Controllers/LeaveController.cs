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
                int employeeId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown(employeeId);
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
            int employeeId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");

            if (!ModelState.IsValid)
            {
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown(employeeId);
                return View(model);
            }

            try
            {
                await _leaveService.SubmitLeaveRequest(employeeId, model);
                TempData["Success"] = "Leave request submitted successfully!";
                return RedirectToAction(nameof(MyLeave));
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error: " + ex.Message;
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown(employeeId);
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
                // Pass 0 to get all types (Admin View)
                var allTypes = await _leaveService.GetLeaveTypesForDropdown(0);
                // Allow assignment for all types EXCEPT Probation/Holiday (as requested they shouldn't have balance)
                ViewBag.LeaveTypes = allTypes.Where(x => x.leave_type != "Probation" && x.leave_type != "Holiday");
                
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
                var allTypes = await _leaveService.GetLeaveTypesForDropdown(0);
                ViewBag.LeaveTypes = allTypes.Where(x => x.leave_type != "Probation" && x.leave_type != "Holiday");
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
                ViewBag.LeaveTypes = await _leaveService.GetLeaveTypesForDropdown(0);
                return View(model);
            }
        }

        // GET: Leave/Leave/ViewFlags
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> ViewFlags()
        {
            try
            {
                var flags = await _leaveService.GetManagerNotes();
                return View(flags);
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error loading flags: " + ex.Message;
                return View(new List<ManagerNoteDto>());
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> ArchiveFlag(int id)
        {
            try
            {
                var message = await _leaveService.ArchiveManagerNote(id);
                TempData["Success"] = message;
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error archiving flag: " + ex.Message;
            }
            return RedirectToAction(nameof(ViewFlags));
        }

        // ==========================================================
        // HR ADMIN: OVERRIDE DECISION
        // ==========================================================
        
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> OverrideDecision(int id)
        {
            try
            {
                // Reuse existing method to get history/details. 
                // Since we don't have a specific "GetOneRequest", we can filter from All History or similar.
                // Or better, let's just make a simple DTO query here or in service.
                // For simplicity/speed matching requirements: Reuse "GetEmployeeHistory" logic or similar.
                // Wait, we need "Read-Only Details". 
                // Let's assume we can fetch it. If not, I'll add a helper in Service.
                
                // Hack: We can use GetEmployeeHistory but we need to know the EmployeeID.
                // Let's create a quick helper in Service for "GetLeaveRequestDetail".
                
                var details = await _leaveService.GetLeaveRequestDetail(id);
                return View(details);
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error loading request: " + ex.Message;
                return RedirectToAction("ManageTypes"); // Fallback
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> OverrideDecision(int id, string status, string reason)
        {
            int adminId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1");
            try
            {
                // Validation
                if (string.IsNullOrWhiteSpace(reason) || string.IsNullOrWhiteSpace(status))
                {
                    TempData["Error"] = "Status and Reason are required.";
                    return RedirectToAction(nameof(OverrideDecision), new { id = id });
                }

                var message = await _leaveService.OverrideLeaveDecision(id, status, reason, adminId);
                TempData["Success"] = message;
                return RedirectToAction("ManageRequests"); // Redirect to list
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Override failed: " + ex.Message;
                return RedirectToAction(nameof(OverrideDecision), new { id = id });
            }
        }

        // ==========================================================
        // HR ADMIN: MANAGE ALL REQUESTS
        // ==========================================================
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> ManageRequests()
        {
            try
            {
                var requests = await _leaveService.GetAllLeaveRequests();
                return View(requests);
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Error loading requests: " + ex.Message;
                return View(new List<LeaveRequestDetailDto>());
            }
        }
    }
}