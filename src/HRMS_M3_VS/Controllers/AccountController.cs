using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using HRMS_M3_VS.Services;
using HRMS_M3_VS.Models;
using Dapper;

namespace HRMS_M3_VS.Controllers
{
    public class AccountController : Controller
    {
        private readonly DbService _db;

        public AccountController(DbService db)
        {
            _db = db;
        }

        [HttpGet]
        public IActionResult Login()
        {
            if (User.Identity!.IsAuthenticated) return RedirectToAction("Index", "Dashboard");
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            if (string.IsNullOrEmpty(model.Email)) return View(model);

            // 1. GET ALL ROWS (Do not use FirstOrDefault here yet)
            // If the user has 3 roles, this returns 3 rows.
            var userRows = await _db.QueryAsync<dynamic>("UserLogin", new
            {
                Email = model.Email,
                Password = model.Password ?? "dummy"
            });

            // 2. CHECK IF USER EXISTS
            if (!userRows.Any())
            {
                TempData["Error"] = "Email not found in system.";
                return View(model);
            }

            // 3. GET BASIC INFO FROM FIRST ROW
            // (ID and Name are the same across all rows)
            var userInfo = userRows.First();

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, ((int)userInfo.employee_id).ToString()),
                new Claim(ClaimTypes.Name, (string)userInfo.full_name)
            };

            // 4. LOOP THROUGH ALL ROWS TO ADD ALL ROLES
            // This ensures User.IsInRole("Manager") works if the user has multiple roles
            foreach (var row in userRows)
            {
                if (!string.IsNullOrEmpty((string)row.role_name))
                {
                    claims.Add(new Claim(ClaimTypes.Role, (string)row.role_name));
                }
            }

            // Fallback: If DB returned no role name, default to "Employee"
            if (!claims.Any(c => c.Type == ClaimTypes.Role))
            {
                claims.Add(new Claim(ClaimTypes.Role, "Employee"));
            }

            // 5. CREATE SESSION
            var claimsIdentity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(claimsIdentity));

            return RedirectToAction("Index", "Dashboard");
        }

        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction("Login", "Account");
        }
    }
}