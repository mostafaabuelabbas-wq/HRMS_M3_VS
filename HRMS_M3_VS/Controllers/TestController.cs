using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Employee.Controllers
{
    [Area("Employee")]
    public class TestController : Controller
    {
        public IActionResult Index()
        {
            return Content("Employee Area is working ✔");
        }
    }
}
