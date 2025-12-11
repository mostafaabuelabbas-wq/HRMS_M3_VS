using Microsoft.AspNetCore.Mvc;
using HRMS_M3_VS.Areas.Employee.Services;
using HRMS_M3_VS.Areas.Employee.Models;

namespace HRMS_M3_VS.Areas.Employee.Controllers
{
    [Area("Employee")]
    public class ContractController : Controller
    {
        private readonly ContractService _service;

        public ContractController(ContractService service)
        {
            _service = service;
        }

        // LIST ALL CONTRACTS
        public async Task<IActionResult> Index()
        {
            var list = await _service.GetAllContractsAsync();
            return View(list);
        }

        // DETAILS
        public async Task<IActionResult> Details(int id)
        {
            var dto = await _service.GetContractDetailsAsync(id);
            if (dto == null) return NotFound();
            return View(dto);
        }

        // CREATE (GET)
        public IActionResult Create(int? employeeId)
        {
            return View(new ContractCreateViewModel
            {
                EmployeeId = employeeId ?? 0,
                StartDate = DateTime.Today,
                EndDate = DateTime.Today.AddYears(1),
                Type = "FullTime"
            });
        }

        // CREATE (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(ContractCreateViewModel vm)
        {
            if (!ModelState.IsValid) return View(vm);

            await _service.CreateContractAsync(vm);
            return RedirectToAction(nameof(Index));
        }

        // EDIT (GET)
        public async Task<IActionResult> Edit(int id)
        {
            var dto = await _service.GetContractDetailsAsync(id);
            if (dto == null) return NotFound();

            return View(new ContractEditViewModel
            {
                ContractId = dto.ContractId,
                Type = dto.Type,
                StartDate = dto.StartDate ?? DateTime.Today,
                EndDate = dto.EndDate ?? DateTime.Today,
                CurrentState = dto.CurrentState
            });
        }

        // EDIT (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(ContractEditViewModel vm)
        {
            if (!ModelState.IsValid) return View(vm);

            await _service.UpdateContractAsync(vm);
            return RedirectToAction(nameof(Details), new { id = vm.ContractId });
        }

        // RENEW (GET)
        public IActionResult Renew(int id)
        {
            return View(new ContractRenewViewModel
            {
                ContractId = id,
                NewEndDate = DateTime.Today.AddYears(1)
            });
        }

        // RENEW (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Renew(ContractRenewViewModel vm)
        {
            if (!ModelState.IsValid) return View(vm);

            await _service.RenewContractAsync(vm);
            return RedirectToAction(nameof(Details), new { id = vm.ContractId });
        }
    }
}
