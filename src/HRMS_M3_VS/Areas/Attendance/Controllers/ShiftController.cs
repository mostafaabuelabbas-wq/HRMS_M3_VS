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

        public IActionResult Create()
        {
            return View(new CreateShiftDto());
        }

        [HttpPost]
        public async Task<IActionResult> Create(CreateShiftDto dto)
        {
            // DEBUGGING: Look at the "Output" window in Visual Studio after clicking Create
            Console.WriteLine($"DEBUG: Name received = {dto.name}");
            Console.WriteLine($"DEBUG: Time received = {dto.start_time}");

            if (!ModelState.IsValid)
                return View(dto);

            await _shift.CreateShift(dto);
            return RedirectToAction("Index");
        }
    }
}
