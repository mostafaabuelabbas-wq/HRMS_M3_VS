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

        // 1. LIST SHIFTS
        public async Task<IActionResult> Index()
        {
            var shifts = await _shift.GetAllShifts();
            return View(shifts);
        }

        // 2. CREATE STANDARD SHIFT (GET)
        public IActionResult Create()
        {
            return View(new CreateShiftDto());
        }

        // 2. CREATE STANDARD SHIFT (POST)
        [HttpPost]
        public async Task<IActionResult> Create(CreateShiftDto dto)
        {
            // Debugging line to check if data arrives
            Console.WriteLine($"DEBUG: Creating Shift - Name: {dto.name}");

            if (!ModelState.IsValid)
                return View(dto);

            await _shift.CreateShift(dto);
            return RedirectToAction("Index");
        }

        // 3. CONFIGURE SPLIT SHIFT (GET)
        public IActionResult ConfigureSplit()
        {
            return View(new SplitShiftDto());
        }

        // 3. CONFIGURE SPLIT SHIFT (POST)
        [HttpPost]
        public async Task<IActionResult> ConfigureSplit(SplitShiftDto dto)
        {
            if (!ModelState.IsValid)
                return View(dto);

            // Call service and get the message from SQL
            string message = await _shift.ConfigureSplitShift(dto);

            // Check if SQL returned an error (Your procedure returns strings starting with 'Error:')
            if (!string.IsNullOrEmpty(message) && message.StartsWith("Error"))
            {
                ViewBag.Error = message;
                return View(dto);
            }

            // If success
            return RedirectToAction("Index");
        }
        // --- ROTATIONAL SHIFT MANAGEMENT ---

        // 1. Create Cycle (GET)
        public IActionResult CreateCycle()
        {
            return View(new ShiftCycleDto());
        }

        // 1. Create Cycle (POST)
        [HttpPost]
        public async Task<IActionResult> CreateCycle(ShiftCycleDto dto)
        {
            if (!ModelState.IsValid) return View(dto);

            await _shift.CreateShiftCycle(dto);
            return RedirectToAction("Index"); // Return to main list
        }

        // 2. Add Shift to Cycle (GET)
        public async Task<IActionResult> AddToCycle()
        {
            // We need lists of Cycles and Shifts for the Dropdowns
            ViewBag.Cycles = await _shift.GetAllCycles();
            ViewBag.Shifts = await _shift.GetAllShifts();

            return View(new AddToCycleDto());
        }

        // 2. Add Shift to Cycle (POST)
        [HttpPost]
        public async Task<IActionResult> AddToCycle(AddToCycleDto dto)
        {
            if (!ModelState.IsValid)
            {
                // Reload dropdowns if validation fails
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

            TempData["Success"] = message;
            return RedirectToAction("Index");
        }
    }
}