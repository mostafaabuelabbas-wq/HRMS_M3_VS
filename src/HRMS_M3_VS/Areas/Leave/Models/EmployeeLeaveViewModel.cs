namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class EmployeeLeaveViewModel
    {
        public IEnumerable<LeaveBalanceDto> Balances { get; set; } = new List<LeaveBalanceDto>();
        public IEnumerable<LeaveHistoryDto> History { get; set; } = new List<LeaveHistoryDto>();
    }
}