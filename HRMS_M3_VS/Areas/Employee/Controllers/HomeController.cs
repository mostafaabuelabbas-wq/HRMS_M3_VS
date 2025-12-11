using HRMS_M3_VS.Areas.Employee.Models;
using HRMS_M3_VS.Areas.Employee.Services;
using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Employee.Controllers
{
    [Area("Employee")]
    public class HomeController : Controller
    {
        private readonly EmployeeService _service;
        private readonly IWebHostEnvironment _env;

        public HomeController(EmployeeService service, IWebHostEnvironment env)
        {
            _service = service;
            _env = env;
        }

        public async Task<IActionResult> Index()
        {
            var employees = await _service.GetAllEmployeesAsync();
            return View(employees);
        }

        public async Task<IActionResult> Profile(int id)
        {
            var emp = await _service.GetEmployeeByIdAsync(id);
            return View(emp);
        }

        public async Task<IActionResult> Edit(int id)
        {
            var emp = await _service.GetEmployeeByIdAsync(id);

            var vm = new EmployeeEditViewModel
            {
                EmployeeId = emp.Employee_Id,
                Email = emp.Email,
                Phone = emp.Phone,
                Address = emp.Address,
                
            };

            return View(vm);
        }

        [HttpPost]
        [HttpPost]
        public async Task<IActionResult> Edit(EmployeeEditViewModel vm)
        {
            if (!ModelState.IsValid)
                return View(vm);

            // ------------------------------
            // 1) Handle Profile Image Upload
            // ------------------------------
            if (vm.ProfileImage != null && vm.ProfileImage.Length > 0)
            {
                var uploadsFolder = Path.Combine(_env.WebRootPath ?? "wwwroot", "images", "employees");

                if (!Directory.Exists(uploadsFolder))
                    Directory.CreateDirectory(uploadsFolder);

                var uniqueFileName = $"{Guid.NewGuid()}{Path.GetExtension(vm.ProfileImage.FileName)}";
                var filePath = Path.Combine(uploadsFolder, uniqueFileName);

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await vm.ProfileImage.CopyToAsync(stream);
                }

                // Save relative path to store in DB
                vm.ExistingImagePath = $"/images/employees/{uniqueFileName}";
            }

            // --------------------------------
            // 2) Update Employee Basic Details
            // --------------------------------
            await _service.UpdateEmployeeAsync(vm);

            // ------------------------------------
            // 3) Update Emergency Contact Details
            // ------------------------------------
            await _service.UpdateEmergencyContactAsync(vm);

            // ------------------------
            // 4) Redirect to Profile
            // ------------------------
            return RedirectToAction("Profile", new { id = vm.EmployeeId });
        }

    }
}
