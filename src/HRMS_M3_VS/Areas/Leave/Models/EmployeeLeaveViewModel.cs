using System.Collections.Generic;

namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class EmployeeLeaveViewModel
    {
        public IEnumerable<LeaveBalanceDto> Balances { get; set; } = new List<LeaveBalanceDto>();

        // ? CHANGED: Now uses LeaveHistoryWithAttachmentsDto instead of LeaveHistoryDto
        public IEnumerable<LeaveHistoryWithAttachmentsDto> History { get; set; } = new List<LeaveHistoryWithAttachmentsDto>();
    }
}