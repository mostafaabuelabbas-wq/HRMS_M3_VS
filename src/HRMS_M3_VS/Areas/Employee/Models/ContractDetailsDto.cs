namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class ContractDetailsDto : ContractDto
    {
        public string? EmployeeEmail { get; set; }
        public string? EmployeePhone { get; set; }
        public int? PositionId { get; set; }
        public string? PositionTitle { get; set; }
        public string? EmployeeName { get; set; }
    }
}
