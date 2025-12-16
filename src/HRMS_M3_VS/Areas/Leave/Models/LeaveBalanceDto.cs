namespace HRMS_M3_VS.Areas.Leave.Models
{
    public class LeaveBalanceDto
    {
        // Matches table [Leave] column 'leave_type'
        public string leave_type { get; set; } = string.Empty;
        
        // Matches table LeaveEntitlement column 'entitlement'
        public decimal entitlement { get; set; } 
        
        // Calculated fields (SQL must alias these exactly as below)
        public decimal days_used { get; set; }
        public decimal days_pending { get; set; }
        public decimal remaining_balance { get; set; }
        public string category { get; set; } = string.Empty;
    }
}