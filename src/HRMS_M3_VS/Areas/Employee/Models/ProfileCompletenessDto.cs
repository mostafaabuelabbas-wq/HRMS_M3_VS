namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class ProfileCompletenessDto
    {
        public int Employee_Id { get; set; }
        public string Full_Name { get; set; } = "";
        public string? Email { get; set; }
        public string? Phone { get; set; }
        public string? Address { get; set; }
        public string? Emergency_Contact_Name { get; set; }
        public string? Emergency_Contact_Phone { get; set; }
        public string? Department_Name { get; set; }
        public string? Position_Title { get; set; }
        public string? Profile_Image { get; set; }

        public int MissingCount { get; set; }
    }
}
