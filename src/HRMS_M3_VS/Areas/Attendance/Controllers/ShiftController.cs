using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Areas.Attendance.Services;
using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    public class ShiftController : Controller
    {
        private readonly ShiftService _shift;

        public ShiftController(ShiftService shift)
        {
            _shift = shift;
        }

        public async Task<IActionResult> Index()
        {
            var shifts = await _shift.GetAllShifts();
            return View(shifts);
        }

        // --- 1. Create Standard Shift ---
        public IActionResult Create() => View(new CreateShiftDto());

        [HttpPost]
        public async Task<IActionResult> Create(CreateShiftDto dto)
        {
            if (!ModelState.IsValid) return View(dto);
            await _shift.CreateShift(dto);
            return RedirectToAction("Index");
        }

        // --- 2. Configure Split Shift ---
        public IActionResult ConfigureSplit() => View(new SplitShiftDto());

        [HttpPost]
        public async Task<IActionResult> ConfigureSplit(SplitShiftDto dto)
        {
            if (!ModelState.IsValid) return View(dto);
            string message = await _shift.ConfigureSplitShift(dto);

            if (!string.IsNullOrEmpty(message) && message.StartsWith("Error"))
            {
                ViewBag.Error = message;
                return View(dto);
            }
            TempData["Success"] = message;
            return RedirectToAction("Index");
        }

        // --- 3. Create Cycle ---
        public IActionResult CreateCycle() => View(new ShiftCycleDto());

        [HttpPost]
        public async Task<IActionResult> CreateCycle(ShiftCycleDto dto)
        {
            if (!ModelState.IsValid) return View(dto);
            await _shift.CreateShiftCycle(dto);
            TempData["Success"] = "Cycle created successfully.";
            return RedirectToAction("Index");
        }

        // --- 4. Link Shift to Cycle (The one that crashed before) ---
        public async Task<IActionResult> AddToCycle()
        {
            // Populate Dropdowns
            ViewBag.Cycles = await _shift.GetAllCycles();
            ViewBag.Shifts = await _shift.GetAllShifts();
            return View(new AddToCycleDto());
        }

        [HttpPost]
        public async Task<IActionResult> AddToCycle(AddToCycleDto dto)
        {
            // Note: Validation might fail if order_number is 0, so check carefully
            if (!ModelState.IsValid)
            {
                ViewBag.Cycles = await _shift.GetAllCycles();
                ViewBag.Shifts = await _shift.GetAllShifts();
                return View(dto);
            }

            string message = await _shift.AddShiftToCycle(dto);

            if (!string.IsNullOrEmpty(message) && message.StartsWith("Error"))
            {
                ViewBag.Error = message;
                ViewBag.Cycles = await _shift.GetAllCycles();
                ViewBag.Shifts = await _shift.GetAllShifts();
                return View(dto);
            }

            TempData["Success"] = message ?? "Shift linked successfully.";
            return RedirectToAction("Index");
        }
        // --- ASSIGN TO EMPLOYEE ---
        public async Task<IActionResult> AssignEmployee()
        {
            // Fetch data from DB
            var employees = await _shift.GetAllEmployees();
            var shifts = await _shift.GetAllShifts();

            // DEBUG: Check if lists are null
            if (employees == null) Console.WriteLine("CRITICAL: Employees list is NULL");
            if (shifts == null) Console.WriteLine("CRITICAL: Shifts list is NULL");

            // Pass to View
            ViewBag.Employees = employees;
            ViewBag.Shifts = shifts;

            return View(new HRMS_M3_VS.Areas.Attendance.Models.AssignToEmployeeDto());
        }

        [HttpPost]
        public async Task<IActionResult> AssignEmployee(AssignToEmployeeDto dto)
        {
            if (!ModelState.IsValid)
            {
                ViewBag.Employees = await _shift.GetAllEmployees();
                ViewBag.Shifts = await _shift.GetAllShifts();
                return View(dto);
            }

            string message = await _shift.AssignToEmployee(dto);

            // Check if your SQL procedure returned an Error
            if (!string.IsNullOrEmpty(message) && message.StartsWith("Error"))
            {
                ViewBag.Error = message;
                ViewBag.Employees = await _shift.GetAllEmployees();
                ViewBag.Shifts = await _shift.GetAllShifts();
                return View(dto);
            }

            TempData["Success"] = message;
            return RedirectToAction("Index");
        }

        // --- ASSIGN TO DEPARTMENT ---
        public async Task<IActionResult> AssignDepartment()
        {
            ViewBag.Departments = await _shift.GetAllDepartments();
            ViewBag.Shifts = await _shift.GetAllShifts();
            return View(new AssignToDepartmentDto());
        }

        [HttpPost]
        public async Task<IActionResult> AssignDepartment(AssignToDepartmentDto dto)
        {
            if (!ModelState.IsValid)
            {
                ViewBag.Departments = await _shift.GetAllDepartments();
                ViewBag.Shifts = await _shift.GetAllShifts();
                return View(dto);
            }

            string message = await _shift.AssignToDepartment(dto);

            if (!string.IsNullOrEmpty(message) && message.StartsWith("Error"))
            {
                ViewBag.Error = message;
                ViewBag.Departments = await _shift.GetAllDepartments();
                ViewBag.Shifts = await _shift.GetAllShifts();
                return View(dto);
            }

            TempData["Success"] = message;
            return RedirectToAction("Index");
        }
        // --- ASSIGN ROTATIONAL (Cycle to Employee) ---
        public async Task<IActionResult> AssignRotational()
        {
            ViewBag.Employees = await _shift.GetAllEmployees();
            ViewBag.Cycles = await _shift.GetAllCycles();
            return View(new AssignRotationalDto());
        }

        [HttpPost]
        public async Task<IActionResult> AssignRotational(AssignRotationalDto dto)
        {
            if (!ModelState.IsValid)
            {
                ViewBag.Employees = await _shift.GetAllEmployees();
                ViewBag.Cycles = await _shift.GetAllCycles();
                return View(dto);
            }

            string message = await _shift.AssignRotationalShift(dto);

            // Error handling
            if (!string.IsNullOrEmpty(message) && message.StartsWith("Error"))
            {
                ViewBag.Error = message;
                ViewBag.Employees = await _shift.GetAllEmployees();
                ViewBag.Cycles = await _shift.GetAllCycles();
                return View(dto);
            }

            TempData["Success"] = message;
            return RedirectToAction("Index");
        }

        // --- ASSIGN CUSTOM (Special Shift to Employee) ---
        public async Task<IActionResult> AssignCustom()
        {
            ViewBag.Employees = await _shift.GetAllEmployees();
            return View(new AssignCustomDto());
        }

        [HttpPost]
        public async Task<IActionResult> AssignCustom(AssignCustomDto dto)
        {
            if (!ModelState.IsValid)
            {
                ViewBag.Employees = await _shift.GetAllEmployees();
                return View(dto);
            }

            string message = await _shift.AssignCustomShift(dto);
            TempData["Success"] = message;
            return RedirectToAction("Index");
        }
    }
}