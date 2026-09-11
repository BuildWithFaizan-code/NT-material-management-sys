using MMSERP.Api.Middleware;
using MMSERP.Api.Repositories;
using MMSERP.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy =
            System.Text.Json.JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DictionaryKeyPolicy =
            System.Text.Json.JsonNamingPolicy.CamelCase;
    });

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

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

app.UseMiddleware<ExceptionMiddleware>();
app.UseCors();
app.MapControllers();

app.Run();
