namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class EmployeeDto
    {
        // Basic employee info
        public int Employee_Id { get; set; }
        public string? Full_Name { get; set; }

        public string? Email { get; set; }
        public string? Phone { get; set; }

        public string? Address { get; set; }
        public string? Profile_Image { get; set; }

        // Emergency contact
        public string? Emergency_Contact_Name { get; set; }
        public string? Relationship { get; set; }
        public string? Emergency_Contact_Phone { get; set; }

        // Department
        public int? Department_Id { get; set; }
        public string? Department_Name { get; set; }
        public string? Department { get; set; }   // Some SPs use this field

        // Position
        public int? Position_Id { get; set; }
        public string? Position_Title { get; set; }
        public string? Position { get; set; }      // Some SPs use this field

        // Employment
        public string? Employment_Status { get; set; }
        public DateTime? Hire_Date { get; set; }

        // Role assignment
        public int? RoleID { get; set; }
        public string? RoleName { get; set; }
    }
}
