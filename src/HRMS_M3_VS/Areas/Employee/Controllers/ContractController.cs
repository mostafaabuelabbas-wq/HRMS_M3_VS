using Microsoft.AspNetCore.Mvc;
using HRMS_M3_VS.Areas.Employee.Services;
using HRMS_M3_VS.Areas.Employee.Models;
using System.Data;

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
       
        public async Task<IActionResult> Create(int? employeeId)
        {
            var vm = new ContractCreateViewModel
            {
                EmployeeId = employeeId ?? 0,
                StartDate = DateTime.Today,
                EndDate = DateTime.Today.AddYears(1),
                Type = "FullTime",
                // LOAD THE DROPDOWN LIST
                Employees = await _service.GetEmployeeSelectListAsync()
            };
            return View(vm);
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

            // Convert to EditViewModel
            var vm = new ContractEditViewModel
            {
                ContractId = dto.ContractId,
                Type = dto.Type,
                StartDate = dto.StartDate ?? DateTime.Today,
                EndDate = dto.EndDate ?? DateTime.Today,
                CurrentState = dto.CurrentState
            };

            return View(vm); // ← CORRECT! Now it's ContractEditViewModel
        }

        // EDIT (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(ContractEditViewModel vm)
        {
            // DEBUG
            Console.WriteLine("=== EDIT POST CALLED ===");
            Console.WriteLine($"ContractId: {vm.ContractId}");
            Console.WriteLine($"Type: {vm.Type}");
            Console.WriteLine($"StartDate: {vm.StartDate}");
            Console.WriteLine($"EndDate: {vm.EndDate}");
            Console.WriteLine($"CurrentState: {vm.CurrentState}");
            Console.WriteLine($"ModelState.IsValid: {ModelState.IsValid}");

            if (!ModelState.IsValid)
            {
                Console.WriteLine("=== VALIDATION FAILED ===");
                foreach (var error in ModelState.Values.SelectMany(v => v.Errors))
                {
                    Console.WriteLine($"Error: {error.ErrorMessage}");
                }
                return View("Edit", vm);
            }

            try
            {
                Console.WriteLine("=== CALLING UPDATE SERVICE ===");
                await _service.UpdateContractAsync(vm);
                Console.WriteLine("=== UPDATE SUCCESSFUL ===");

                TempData["SuccessMessage"] = "Contract updated successfully!";
                return RedirectToAction(nameof(Details), new { id = vm.ContractId });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"=== EXCEPTION: {ex.Message} ===");
                TempData["ErrorMessage"] = ex.Message;
                return View("Edit", vm);
            }
        }

        // RENEW (GET)
        public async Task<IActionResult> Renew(int id)
        {
            var contract = await _service.GetContractDetailsAsync(id);

            if (contract == null)
                return NotFound();

            return View(new ContractRenewViewModel
            {
                ContractId = id,
                NewEndDate = contract.EndDate?.AddYears(1) ?? DateTime.Today.AddYears(1),
                EmployeeName = contract.EmployeeName,
                CurrentType = contract.Type,
                CurrentEndDate = contract.EndDate
            });
        }
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Renew(ContractRenewViewModel vm)
        {
            if (!ModelState.IsValid)
            {
                var contract = await _service.GetContractDetailsAsync(vm.ContractId);
                vm.EmployeeName = contract?.EmployeeName;  // ← FIXED
                vm.CurrentType = contract?.Type;
                vm.CurrentEndDate = contract?.EndDate;
                return View(vm);
            }

            try
            {
                int newContractId = await _service.RenewContractAsync(vm);
                TempData["SuccessMessage"] = "Contract renewed successfully!";
                return RedirectToAction(nameof(Details), new { id = newContractId });
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = ex.Message;

                var contract = await _service.GetContractDetailsAsync(vm.ContractId);
                vm.EmployeeName = contract?.EmployeeName;  // ← FIXED
                vm.CurrentType = contract?.Type;
                vm.CurrentEndDate = contract?.EndDate;

                return View(vm);
            }
        }
    }
}
