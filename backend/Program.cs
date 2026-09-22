using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;
using MMSERP.Api.Middleware;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;
using MMSERP.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// ============================================================================
// 1. Secrets & Environment Validation
// ============================================================================
var jwtSigningKey = Environment.GetEnvironmentVariable("JWT_SIGNING_KEY")
    ?? builder.Configuration["JWT_SIGNING_KEY"];
if (string.IsNullOrWhiteSpace(jwtSigningKey))
{
    throw new InvalidOperationException(
        "FATAL STARTUP ERROR: Environment variable 'JWT_SIGNING_KEY' is missing. " +
        "A cryptographically secure secret of at least 256 bits (32 characters) must be configured.");
}

var keyBytes = Encoding.UTF8.GetBytes(jwtSigningKey);
if (keyBytes.Length < 32)
{
    throw new InvalidOperationException(
        $"FATAL STARTUP ERROR: 'JWT_SIGNING_KEY' is {keyBytes.Length * 8} bits. " +
        "HS256 requires a minimum of 256 bits (at least 32 UTF-8 characters).");
}

// ============================================================================
// 2. Controllers & JSON Options
// ============================================================================
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy =
            System.Text.Json.JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DictionaryKeyPolicy =
            System.Text.Json.JsonNamingPolicy.CamelCase;
    });

// ============================================================================
// 3. CORS Configuration (Explicit Allowlist + AllowCredentials)
// ============================================================================
var configuredOrigins = Environment.GetEnvironmentVariable("CORS_ALLOWED_ORIGINS");
var allowedOriginsList = new List<string>
{
    "https://nt-material-management-sys.netlify.app",
    "http://localhost:3000",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:5173",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5000",
    "http://127.0.0.1:8080"
};

if (!string.IsNullOrWhiteSpace(configuredOrigins))
{
    foreach (var origin in configuredOrigins.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
    {
        if (!allowedOriginsList.Contains(origin))
        {
            allowedOriginsList.Add(origin);
        }
    }
}

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(allowedOriginsList.ToArray())
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

// ============================================================================
// 4. IP-Based Rate Limiting for Auth Endpoints (5 attempts/minute/IP)
// ============================================================================
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("LoginRateLimit", httpContext =>
    {
        var clientIp = httpContext.Request.Headers.TryGetValue("X-Forwarded-For", out var forwarded)
            ? forwarded.FirstOrDefault()?.Split(',')[0].Trim()
            : httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown_client";

        return RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: clientIp,
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(1),
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            });
    });

    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        context.HttpContext.Response.ContentType = "application/json";
        var response = ApiResponse<string>.Fail("Too many login attempts. Please wait a minute and try again.");
        await context.HttpContext.Response.WriteAsJsonAsync(response, cancellationToken: token);
    };
});

// ============================================================================
// 5. JWT Authentication (HS256, ClockSkew = TimeSpan.Zero)
// ============================================================================
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(keyBytes),
        ValidateIssuer = false,
        ValidateAudience = false,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero // Crucial: default 5 min skew is strictly disabled
    };
});

// ============================================================================
// 6. Global Authorization Policy & Option A Development Bypass
// ============================================================================
builder.Services.AddAuthorization(options =>
{
    // Global fallback policy: every endpoint requires authentication unless marked [AllowAnonymous]
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

// Register Option A Development Bypass ONLY in Development environment
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddSingleton<IAuthorizationHandler, AllowAnonymousInDevelopmentHandler>();
}

// ============================================================================
// 7. Dependency Injection - Repositories & Services
// ============================================================================
builder.Services.AddScoped<IAuthRepository, AuthRepository>();
builder.Services.AddScoped<IAuthService, AuthService>();

builder.Services.AddScoped<IDashboardRepository, SqlDashboardRepository>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<IProjectMasterRepository, ProjectMasterRepository>();
builder.Services.AddScoped<IProjectMasterService, ProjectMasterService>();
builder.Services.AddScoped<ILocationMasterRepository, LocationMasterRepository>();
builder.Services.AddScoped<ILocationMasterService, LocationMasterService>();
builder.Services.AddScoped<IStoreMasterRepository, StoreMasterRepository>();
builder.Services.AddScoped<IStoreMasterService, StoreMasterService>();
builder.Services.AddScoped<IOperatorMasterRepository, OperatorMasterRepository>();
builder.Services.AddScoped<IOperatorMasterService, OperatorMasterService>();
builder.Services.AddScoped<IOperationMasterRepository, OperationMasterRepository>();
builder.Services.AddScoped<IOperationMasterService, OperationMasterService>();
builder.Services.AddScoped<IDepartmentMasterRepository, DepartmentMasterRepository>();
builder.Services.AddScoped<IDepartmentMasterService, DepartmentMasterService>();
builder.Services.AddScoped<ISubDepartmentMasterRepository, SubDepartmentMasterRepository>();
builder.Services.AddScoped<ISubDepartmentMasterService, SubDepartmentMasterService>();
builder.Services.AddScoped<IHeadMasterRepository, HeadMasterRepository>();
builder.Services.AddScoped<IHeadMasterService, HeadMasterService>();
builder.Services.AddScoped<IBookMasterRepository, BookMasterRepository>();
builder.Services.AddScoped<IBookMasterService, BookMasterService>();
builder.Services.AddScoped<INonStockableItemRepository, NonStockableItemRepository>();
builder.Services.AddScoped<INonStockableItemService, NonStockableItemService>();
builder.Services.AddScoped<IChargesMasterRepository, ChargesMasterRepository>();
builder.Services.AddScoped<IChargesMasterService, ChargesMasterService>();
builder.Services.AddScoped<IFabricSizeMasterRepository, FabricSizeMasterRepository>();
builder.Services.AddScoped<IFabricSizeMasterService, FabricSizeMasterService>();
builder.Services.AddScoped<IMakersMasterRepository, MakersMasterRepository>();
builder.Services.AddScoped<IMakersMasterService, MakersMasterService>();
builder.Services.AddScoped<ICapitalConsumableMasterRepository, CapitalConsumableMasterRepository>();
builder.Services.AddScoped<ICapitalConsumableMasterService, CapitalConsumableMasterService>();
builder.Services.AddScoped<IGradeMasterRepository, GradeMasterRepository>();
builder.Services.AddScoped<IGradeMasterService, GradeMasterService>();
builder.Services.AddScoped<IMainGroupMasterRepository, MainGroupMasterRepository>();
builder.Services.AddScoped<IMainGroupMasterService, MainGroupMasterService>();
builder.Services.AddScoped<IGroupMasterRepository, GroupMasterRepository>();
builder.Services.AddScoped<IGroupMasterService, GroupMasterService>();
builder.Services.AddScoped<IGroupMasterDefinitionRepository, GroupMasterDefinitionRepository>();
builder.Services.AddScoped<IGroupMasterDefinitionService, GroupMasterDefinitionService>();

var app = builder.Build();

// ============================================================================
// 8. Production Startup Guard & Development Warning Logging
// ============================================================================
if (app.Environment.IsProduction())
{
    // Fail-fast guard: ensure bypass handler is NEVER registered in production
    var handlers = app.Services.GetServices<IAuthorizationHandler>();
    if (handlers.Any(h => h is AllowAnonymousInDevelopmentHandler))
    {
        throw new InvalidOperationException(
            "FATAL SECURITY FAILURE: AllowAnonymousInDevelopmentHandler is registered in a PRODUCTION environment! " +
            "Refusing to start.");
    }
}
else if (app.Environment.IsDevelopment())
{
    var logger = app.Services.GetRequiredService<ILogger<Program>>();
    logger.LogWarning("*******************************************************************************");
    logger.LogWarning("⚠️  AUTH BYPASS ACTIVE — DEVELOPMENT ONLY — DO NOT DEPLOY THIS BUILD.  ⚠️");
    logger.LogWarning("*******************************************************************************");
}

// ============================================================================
// 9. HTTP Request Pipeline
// ============================================================================
app.UseMiddleware<ExceptionMiddleware>();

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
    app.UseHsts();
}

app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
