using HRMS_M3_VS.Areas.Employee.Models;
using HRMS_M3_VS.Services;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace HRMS_M3_VS.Areas.Employee.Services
{
    public class ContractService
    {
        private readonly DbService _db;

        public ContractService(DbService db)
        {
            _db = db;
        }

        public Task<IEnumerable<ContractDto>> GetAllContractsAsync()
            => _db.QueryAsync<ContractDto>("GetAllContracts", null);

        public Task<IEnumerable<ContractDto>> GetEmployeeContractsAsync(int employeeId)
            => _db.QueryAsync<ContractDto>("GetEmployeeContracts", new { EmployeeID = employeeId });

        public async Task<ContractDetailsDto?> GetContractDetailsAsync(int contractId)
        {
            var data = await _db.QueryAsync<ContractDetailsDto>("GetContractDetails", new { ContractID = contractId });
            return data.FirstOrDefault();
        }

        public Task CreateContractAsync(ContractCreateViewModel vm)
            => _db.ExecuteAsync("CreateContract", new
            {
                vm.EmployeeId,
                vm.Type,
                vm.StartDate,
                vm.EndDate
            });

        public Task UpdateContractAsync(ContractEditViewModel vm)
            => _db.ExecuteAsync("UpdateContract", new
            {
                vm.ContractId,
                vm.Type,
                vm.StartDate,
                vm.EndDate,
                vm.CurrentState
            });

        public async Task<int> RenewContractAsync(ContractRenewViewModel vm)
        {
            // Call stored procedure and capture the new contract ID
            var result = await _db.QueryAsync<int>("RenewContract", new
            {
                ContractID = vm.ContractId,
                NewEndDate = vm.NewEndDate
            });

            int newContractId = result.FirstOrDefault();

            // Send notification using the NEW contract ID
            await _db.ExecuteAsync("SendContractRenewalNotification", new
            {
                ContractID = newContractId
            });

            return newContractId; // Return the new ID
        }
        public async Task<IEnumerable<SelectListItem>> GetEmployeeSelectListAsync()
        {
            // FIX: Use the Stored Procedure name, not raw SQL
            var employees = await _db.QueryAsync<dynamic>("GetEmployeeSimpleList", null);

            return employees.Select(e => new SelectListItem
            {
                Value = e.employee_id.ToString(),
                Text = e.full_name
            });
        }
    }
}
