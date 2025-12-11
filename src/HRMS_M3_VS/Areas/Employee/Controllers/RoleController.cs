using Microsoft.AspNetCore.Mvc;
using HRMS_M3_VS.Areas.Employee.Services;
using HRMS_M3_VS.Areas.Employee.Models;

namespace HRMS_M3_VS.Areas.Employee.Controllers
{
    [Area("Employee")]
    public class RoleController : Controller
    {
        private readonly RoleService _roleService;

        public RoleController(RoleService roleService)
        {
            _roleService = roleService;
        }

        // LIST ALL EMPLOYEES + ROLES
        public async Task<IActionResult> Index()
        {
            var data = await _roleService.GetAllEmployeesWithRolesAsync();

            var vm = data.Select(e => new AssignRoleViewModel
            {
                EmployeeId = e.Employee_Id,
                FullName = e.Full_Name,
                Department = e.Department,
                CurrentRoleId = e.RoleId,
                CurrentRoleName = e.RoleName
            }).ToList();

            return View(vm);
        }

        // EDIT ROLE
        public async Task<IActionResult> Edit(int id)
        {
            var employees = await _roleService.GetAllEmployeesWithRolesAsync();
            var employee = employees.FirstOrDefault(x => x.Employee_Id == id);

            if (employee == null)
                return NotFound();

            var roles = await _roleService.GetRolesAsync();

            var vm = new AssignRoleViewModel
            {
                EmployeeId = employee.Employee_Id,
                FullName = employee.Full_Name,
                Department = employee.Department,
                CurrentRoleId = employee.RoleId,
                CurrentRoleName = employee.RoleName,
                Roles = roles.ToList()
            };

            return View(vm);
        }

        // SAVE ROLE
        [HttpPost]
        public async Task<IActionResult> Edit(AssignRoleViewModel vm)
        {
            await _roleService.AssignRoleAsync(vm.EmployeeId, vm.NewRoleId);

            TempData["Success"] = "Role updated successfully!";
            return RedirectToAction("Index");
        }
    }
}
