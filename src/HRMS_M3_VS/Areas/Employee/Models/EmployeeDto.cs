namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class EmployeeDto
    {
        public int Employee_Id { get; set; }

        // Add '?' to make these nullable. 
        // This stops the "Non-nullable property must contain a non-null value" warnings.
        public string? Full_Name { get; set; }
        public string? Email { get; set; }
        public string? Phone { get; set; }
        public string? Address { get; set; }
        public byte[]? Profile_Image { get; set; }

        // Emergency Contact Info
        public string? Emergency_Contact_Name { get; set; }
        public string? Relationship { get; set; }
        public string? Emergency_Contact_Phone { get; set; }

        // Mapped Properties
        // We renamed these to 'Department' and 'Position' to match the new SP logic
        public string? Department { get; set; }
        public string? Position { get; set; }

        public string? Employment_Status { get; set; }
        public DateTime? Hire_Date { get; set; }

        // Role Info
        public int? RoleID { get; set; }
        public string? RoleName { get; set; }
    }
}