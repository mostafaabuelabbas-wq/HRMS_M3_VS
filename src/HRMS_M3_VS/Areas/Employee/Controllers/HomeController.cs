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
            // SECURITY FIX: Ensure the user is editing THEIR OWN profile
            // SECURITY FIX: Ensure the user is editing THEIR OWN profile OR is HR Admin
            var loggedInUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            bool isHRAdmin = User.IsInRole("HRAdmin");

            if (!isHRAdmin && loggedInUserId != null && int.Parse(loggedInUserId) != id)
            {
                return Forbid(); 
            }

            var emp = await _service.GetEmployeeByIdAsync(id);
            if (emp == null) return NotFound();

            var vm = new EmployeeEditViewModel
            {
                EmployeeId = emp.Employee_Id,
                Email = emp.Email,
                Phone = emp.Phone,
                Address = emp.Address,
                ExistingImageBytes = emp.Profile_Image,

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
            byte[]? finalBytes = currentEmp?.Profile_Image; 

            // 2. Logic: Handle changes

            // Case A: User checked "Remove Photo" -> Force Delete
            if (model.RemoveImage)
            {
                finalBytes = null;
            }

            // Case B: User uploaded a NEW photo -> Force Update (Overrides everything)
            if (model.ProfileImage != null)
            {
                using (var memoryStream = new MemoryStream())
                {
                    await model.ProfileImage.CopyToAsync(memoryStream);
                    finalBytes = memoryStream.ToArray();
                }
            }

            // Update the model with the final decision
            model.ExistingImageBytes = finalBytes;

            // 3. Save Personal Info
            await _service.UpdateEmployeeAsync(model);

            // 4. Save Emergency Info
            await _service.UpdateEmergencyContactAsync(model);

            return RedirectToAction("Profile", new { id = model.EmployeeId });
        }

    }
}
