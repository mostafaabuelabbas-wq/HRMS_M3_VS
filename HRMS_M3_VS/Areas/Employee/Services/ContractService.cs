using HRMS_M3_VS.Services;
using HRMS_M3_VS.Areas.Employee.Models;

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

        public async Task RenewContractAsync(ContractRenewViewModel vm)
        {
            await _db.ExecuteAsync("RenewContract", new
            {
                vm.ContractId,
                vm.NewEndDate
            });

            // Send notification
            await _db.ExecuteAsync("SendContractRenewalNotification", new
            {
                ContractID = vm.ContractId
            });
        }
    }
}
