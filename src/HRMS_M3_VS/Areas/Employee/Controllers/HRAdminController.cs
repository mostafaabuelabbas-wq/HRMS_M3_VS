using Microsoft.AspNetCore.Mvc;
using HRMS_M3_VS.Areas.Employee.Services;
using Microsoft.AspNetCore.Authorization;

namespace HRMS_M3_VS.Areas.Employee.Controllers
{
    [Area("Employee")]
    [Authorize(Roles = "HRAdmin")]
    public class HRAdminController : Controller
    {
        private readonly EmployeeService _service;

        public HRAdminController(EmployeeService service)
        {
            _service = service;
        }

        public async Task<IActionResult> ProfileCompleteness()
        {
            var list = await _service.GetIncompleteProfilesAsync();
            return View(list);
        }
    }
}
