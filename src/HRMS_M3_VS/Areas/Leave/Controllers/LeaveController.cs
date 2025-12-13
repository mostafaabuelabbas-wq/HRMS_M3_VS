using HRMS_M3_VS.Areas.Leave.Services;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

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

        // Manager: View pending leave requests
        public async Task<IActionResult> Index()
        {
            int managerId = int.Parse(
                User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1"
            );

            var requests = await _leaveService.GetPendingLeaveRequests(managerId);
            return View(requests);
        }

        // Manager: Approve leave request
        [HttpPost]
        public async Task<IActionResult> Approve(int id)
        {
            int managerId = int.Parse(
                User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1"
            );

            try
            {
                var message = await _leaveService.ApproveLeaveRequest(id, managerId);
                TempData["Success"] = message;
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }

        // Manager: Reject leave request
        [HttpPost]
        public async Task<IActionResult> Reject(int id, string reason)
        {
            int managerId = int.Parse(
                User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "1"
            );

            try
            {
                var message = await _leaveService.RejectLeaveRequest(id, managerId, reason);
                TempData["Success"] = message;
            }
            catch (Exception ex)
            {
                TempData["Error"] = ex.Message;
            }

            return RedirectToAction(nameof(Index));
        }
    }
}