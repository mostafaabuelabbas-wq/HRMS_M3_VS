namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class AssignRoleViewModel
    {
        public int EmployeeId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Department { get; set; } = string.Empty;

        public int? CurrentRoleId { get; set; }
        public string? CurrentRoleName { get; set; }

        public int NewRoleId { get; set; }

        public List<RoleDto> Roles { get; set; } = new();
    }
}
