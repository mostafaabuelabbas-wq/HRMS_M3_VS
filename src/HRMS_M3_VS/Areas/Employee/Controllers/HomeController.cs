using HRMS_M3_VS.Areas.Employee.Models;
using HRMS_M3_VS.Areas.Employee.Services;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

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

        // GET: /Employee/Home/MyProfile
        public IActionResult MyProfile()
        {
            // 1. Get the logged-in User's ID from the Cookie
            var userIdString = User.FindFirstValue(ClaimTypes.NameIdentifier);

            // 2. Safety Check: If not logged in, kick them out
            if (string.IsNullOrEmpty(userIdString))
            {
                return RedirectToAction("Login", "Account", new { area = "" });
            }

            // 3. Parse the ID and redirect to THEIR specific profile
            int userId = int.Parse(userIdString);

            return RedirectToAction("Profile", new { id = userId });
        }
        public async Task<IActionResult> Profile(int id)
        {
            var emp = await _service.GetEmployeeByIdAsync(id);

            if (emp == null)
            {
                // Bonus: Return a "User Not Found" view or redirect with a generic error
                TempData["Error"] = "Employee not found.";
                return RedirectToAction("Index", "Home");
            }

            return View(emp);
        }

        [HttpGet]
        public async Task<IActionResult> Edit(int id)
        {
            var emp = await _service.GetEmployeeByIdAsync(id);
            if (emp == null) return NotFound();

            var vm = new EmployeeEditViewModel
            {
                EmployeeId = emp.Employee_Id,
                Email = emp.Email,
                Phone = emp.Phone,
                Address = emp.Address,
                ExistingImagePath = emp.Profile_Image,

                // --- ARE THESE LINES MISSING? ---
                EmergencyContactName = emp.Emergency_Contact_Name,
                EmergencyRelationship = emp.Relationship,
                EmergencyContactPhone = emp.Emergency_Contact_Phone
                // --------------------------------
            };

            return View(vm);
        }


        [HttpPost]
        public async Task<IActionResult> Edit(EmployeeEditViewModel model)
        {
            // 1. SAFETY STEP: Fetch the current data from the DB to be sure
            // This prevents accidental deletion if the hidden field fails
            var currentEmp = await _service.GetEmployeeByIdAsync(model.EmployeeId);
            string finalPath = currentEmp?.Profile_Image; // Start with what is currently in the DB

            // 2. Logic: Handle changes

            // Case A: User checked "Remove Photo" -> Force Delete
            if (model.RemoveImage)
            {
                finalPath = null;
            }

            // Case B: User uploaded a NEW photo -> Force Update (Overrides everything)
            if (model.ProfileImage != null)
            {
                string folderPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", "profiles");
                if (!Directory.Exists(folderPath)) Directory.CreateDirectory(folderPath);

                string uniqueFileName = model.EmployeeId + "_" + model.ProfileImage.FileName;
                string filePath = Path.Combine(folderPath, uniqueFileName);

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await model.ProfileImage.CopyToAsync(stream);
                }

                finalPath = "/images/profiles/" + uniqueFileName;
            }

            // Update the model with the final decision
            model.ExistingImagePath = finalPath;

            // 3. Save Personal Info
            await _service.UpdateEmployeeAsync(model);

            // 4. Save Emergency Info
            await _service.UpdateEmergencyContactAsync(model);

            return RedirectToAction("Profile", new { id = model.EmployeeId });
        }

    }
}
