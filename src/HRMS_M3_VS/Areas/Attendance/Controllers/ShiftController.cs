using HRMS_M3_VS.Areas.Attendance.Models;
using HRMS_M3_VS.Areas.Attendance.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    [Authorize] // Require Login for everything in this controller
    public class ShiftController : Controller
    {
        private readonly ShiftService _shift;

        public ShiftController(ShiftService shift)
        {
            _shift = shift;
        }

        // Everyone (Admins, HR, Managers) can view the list
        public async Task<IActionResult> Index()
        {
            var shifts = await _shift.GetAllShifts();
            return View(shifts);
        }

        // =========================================================
        // REQ (a): System Admins can create shift types.
        // =========================================================
        [Authorize(Roles = "SystemAdmin")]
        public IActionResult Create() => View(new CreateShiftDto());

        [HttpPost]
        [Authorize(Roles = "SystemAdmin")]
        public async Task<IActionResult> Create(CreateShiftDto dto)
        {
            if (!ModelState.IsValid) return View(dto);
            await _shift.CreateShift(dto);
            return RedirectToAction("Index");
        }

        // =========================================================
        // REQ (b): HR Admins can configure split & rotational shifts.
        // (SystemAdmin included as they usually have full access)
        // =========================================================

        // 1. Split Shifts
        [Authorize(Roles = "HRAdmin")]
        public IActionResult ConfigureSplit() => View(new SplitShiftDto());

        [HttpPost]
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
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

        // 2. Rotational Cycles
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public IActionResult CreateCycle() => View(new ShiftCycleDto());

        [HttpPost]
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> CreateCycle(ShiftCycleDto dto)
        {
            if (!ModelState.IsValid) return View(dto);
            await _shift.CreateShiftCycle(dto);
            TempData["Success"] = "Cycle created successfully.";
            return RedirectToAction("Index");
        }

        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> AddToCycle()
        {
            ViewBag.Cycles = await _shift.GetAllCycles();
            ViewBag.Shifts = await _shift.GetAllShifts();
            return View(new AddToCycleDto());
        }

        [HttpPost]
        [Authorize(Roles = "HRAdmin,SystemAdmin")]
        public async Task<IActionResult> AddToCycle(AddToCycleDto dto)
        {
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

        // =========================================================
        // REQ (c): System Admin & Manager can assign Standard/Dept.
        // =========================================================

        // 1. Assign Standard to Employee (Also handles "Update" via SQL logic)
        [Authorize(Roles = "Manager,SystemAdmin")]
        public async Task<IActionResult> AssignEmployee()
        {
            ViewBag.Employees = await _shift.GetAllEmployees();
            ViewBag.Shifts = await _shift.GetAllShifts();
            return View(new AssignToEmployeeDto());
        }

        [HttpPost]
        [Authorize(Roles = "Manager,SystemAdmin")]
        public async Task<IActionResult> AssignEmployee(AssignToEmployeeDto dto)
        {
            // ... Validation ...
            await _shift.AssignToEmployee(dto);
            return RedirectToAction("Index");
        }

        // 2. Assign to Department
        [Authorize(Roles = "Manager,SystemAdmin")]
        public async Task<IActionResult> AssignDepartment()
        {
            ViewBag.Departments = await _shift.GetAllDepartments();
            ViewBag.Shifts = await _shift.GetAllShifts();
            return View(new AssignToDepartmentDto());
        }

        [HttpPost]
        [Authorize(Roles = "Manager,SystemAdmin")]
        public async Task<IActionResult> AssignDepartment(AssignToDepartmentDto dto)
        {
            // ... Validation ...
            await _shift.AssignToDepartment(dto);
            return RedirectToAction("Index");
        }

        // =========================================================
        // REQ (d): ONLY System Admin can assign Rotational & Custom.
        // =========================================================

        // 1. Assign Rotational (Cycle)
        [Authorize(Roles = "SystemAdmin")] // <--- STRICT: Manager cannot do this
        public async Task<IActionResult> AssignRotational()
        {
            ViewBag.Employees = await _shift.GetAllEmployees();
            ViewBag.Cycles = await _shift.GetAllCycles();
            return View(new AssignRotationalDto());
        }

        [HttpPost]
        [Authorize(Roles = "SystemAdmin")]
        public async Task<IActionResult> AssignRotational(AssignRotationalDto dto)
        {
            // ... Validation ...
            await _shift.AssignRotationalShift(dto);
            return RedirectToAction("Index");
        }

        // 2. Assign Custom (Special)
        [Authorize(Roles = "SystemAdmin")] // <--- STRICT: Manager cannot do this
        public async Task<IActionResult> AssignCustom()
        {
            ViewBag.Employees = await _shift.GetAllEmployees();
            return View(new AssignCustomDto());
        }

        [HttpPost]
        [Authorize(Roles = "SystemAdmin")]
        public async Task<IActionResult> AssignCustom(AssignCustomDto dto)
        {
            // ... Validation ...
            await _shift.AssignCustomShift(dto);
            return RedirectToAction("Index");
        }
    }
}