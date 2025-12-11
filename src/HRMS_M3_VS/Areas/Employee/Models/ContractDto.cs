namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class ContractDto
    {
        public int ContractId { get; set; }
        public string Type { get; set; } = "";
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public string? CurrentState { get; set; }

        // Employee quick info
        public int? EmployeeId { get; set; }
        public string? FullName { get; set; }
        public string? DepartmentName { get; set; }

        // Basic subtype fields (nullable)
        public int? Ft_LeaveEntitlement { get; set; }
        public string? Ft_InsuranceEligibility { get; set; }
        public int? Ft_WeeklyHours { get; set; }

        public int? Pt_WorkingHours { get; set; }
        public decimal? Pt_HourlyRate { get; set; }

        public string? Consultant_ProjectScope { get; set; }
        public decimal? Consultant_Fees { get; set; }
        public string? Consultant_PaymentSchedule { get; set; }

        public string? Internship_Mentoring { get; set; }
        public string? Internship_Evaluation { get; set; }
        public string? Internship_StipendRelated { get; set; }
    }
}
