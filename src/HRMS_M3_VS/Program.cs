using HRMS_M3_VS.Areas.Attendance.Services;
using HRMS_M3_VS.Areas.Employee.Services;
using HRMS_M3_VS.Services;
using Microsoft.AspNetCore.Authentication.Cookies; // <--- 1. ADD THIS NAMESPACE
using Microsoft.Data.SqlClient;
using System.Security.Claims;

var builder = WebApplication.CreateBuilder(args);

// Add MVC support
builder.Services.AddControllersWithViews();

// Register database + application services
builder.Services.AddScoped<DbService>();
builder.Services.AddScoped<EmployeeService>();
builder.Services.AddScoped<RoleService>();
builder.Services.AddScoped<ContractService>();
builder.Services.AddScoped<ShiftService>();
builder.Services.AddScoped<MissionService>();
builder.Services.AddScoped<AttendanceAdminService>();
builder.Services.AddScoped<TeamAttendanceService>();
builder.Services.AddScoped<TrackingService>();


// ==================================================================
// 2. ADD THIS BLOCK BEFORE 'builder.Build()'
// This tells the app how to handle logins (using Cookies)
// ==================================================================
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
{
options.LoginPath = "/Account/Login";  // If not logged in, go here
options.LogoutPath = "/Account/Logout";
options.ExpireTimeSpan = TimeSpan.FromMinutes(60); // Auto logout after 1 hour
});
// ==================================================================


builder.Services.AddScoped<TrackingService>();
// Optional: Test DB connection on startup

try
{
    using var conn = new SqlConnection(builder.Configuration.GetConnectionString("HRMS"));
    conn.Open();
    Console.WriteLine("DATABASE CONNECTION SUCCESSFUL ✔");
}
catch (Exception ex)
{
    Console.WriteLine("DATABASE CONNECTION FAILED ❌");
    Console.WriteLine(ex.Message);
}

var app = builder.Build();

// Configure the HTTP request pipeline
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();
app.UseAuthentication(); // <--- Checks "Who are you?" (Reads the Cookie)
app.UseAuthorization();  // <--- Checks "Are you allowed?" (Reads the Role)


// -----------------------------------------------------------
// TEMPORARY MOCK LOGIN - MUST BE BEFORE UseAuthorization()
// -----------------------------------------------------------
/*
app.Use(async (context, next) =>
{
    context.User = new ClaimsPrincipal(
        new ClaimsIdentity(new[]
        {
             new Claim(ClaimTypes.Name, "Dev SuperUser"),
            
            // Grant ALL roles for development
            new Claim(ClaimTypes.Role, "SystemAdmin"),
            new Claim(ClaimTypes.Role, "HRAdmin"),
            new Claim(ClaimTypes.Role, "Manager"),
            new Claim(ClaimTypes.Role, "Employee")
        }, "mock"));

    await next.Invoke();
});
*/
// Authorization checks happen AFTER the mock user



// -----------------------------------------------------------
// AREA ROUTE (must come BEFORE default route)
// -----------------------------------------------------------
app.MapControllerRoute(
    name: "areas",
    pattern: "{area:exists}/{controller=Home}/{action=Index}/{id?}");


// -----------------------------------------------------------
// DEFAULT ROUTE (This determines the landing page)
// -----------------------------------------------------------
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Account}/{action=Login}/{id?}");
// ^^^ CHANGE THIS: It used to be Home/Index or Dashboard/Index

app.Run();
