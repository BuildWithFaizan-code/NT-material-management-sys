using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public class AiService : IAiService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly ILogger<AiService> _logger;

        private const string SystemPrompt = 
            "You are Gemini Copilot, the intelligent AI assistant embedded inside the NewTech Material Management System (NT-MMS). " +
            "You assist enterprise users with managing inventory, master records (Stores, Items, Departments, Locations), " +
            "Bill of Materials (BOM creation, formulas, closing), Procurement (Purchase Orders, Approvals, Advance payments), " +
            "Stock Transfers, Indents, and Role-Based Access Control. Be concise, polite, professional, and use clear markdown formatting.";

        public AiService(
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration,
            ILogger<AiService> logger)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<AiChatResponseDto> ChatAsync(AiChatRequestDto request)
        {
            var apiKey = !string.IsNullOrWhiteSpace(request.ClientApiKey)
                ? request.ClientApiKey.Trim()
                : (_configuration["GEMINI_API_KEY"] ?? Environment.GetEnvironmentVariable("GEMINI_API_KEY"))?.Trim();

            if (!string.IsNullOrWhiteSpace(apiKey))
            {
                try
                {
                    var liveReply = await CallGeminiApiAsync(apiKey, request);
                    if (!string.IsNullOrWhiteSpace(liveReply))
                    {
                        return new AiChatResponseDto
                        {
                            Reply = liveReply,
                            Model = "gemini-1.5-flash",
                            IsLiveGemini = true
                        };
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Live Gemini API call failed or timed out. Falling back to local intelligence.");
                }
            }

            // Fallback: Intelligent NT-MMS Domain Knowledge Engine
            var localReply = GenerateKnowledgeResponse(request.Message);
            return new AiChatResponseDto
            {
                Reply = localReply,
                Model = "NT-MMS Knowledge Copilot",
                IsLiveGemini = false
            };
        }

        private async Task<string?> CallGeminiApiAsync(string apiKey, AiChatRequestDto request)
        {
            var client = _httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(25);

            var contents = new List<object>();

            // Add conversation history
            if (request.History != null)
            {
                foreach (var h in request.History.TakeLast(6))
                {
                    var role = h.Role.ToLowerInvariant() == "model" ? "model" : "user";
                    contents.Add(new
                    {
                        role = role,
                        parts = new[] { new { text = h.Content } }
                    });
                }
            }

            // Add the current prompt
            contents.Add(new
            {
                role = "user",
                parts = new[] { new { text = request.Message } }
            });

            var payload = new
            {
                systemInstruction = new
                {
                    parts = new[] { new { text = SystemPrompt } }
                },
                contents = contents,
                generationConfig = new
                {
                    temperature = 0.7,
                    maxOutputTokens = 1000
                }
            };

            var jsonContent = new StringContent(
                JsonSerializer.Serialize(payload),
                Encoding.UTF8,
                "application/json");

            // Use gemini-1.5-flash
            var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={apiKey}";
            var response = await client.PostAsync(url, jsonContent);

            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                _logger.LogWarning("Gemini API HTTP {Status}: {Body}", response.StatusCode, errorBody);
                return null;
            }

            var responseJson = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(responseJson);

            if (doc.RootElement.TryGetProperty("candidates", out var candidates) &&
                candidates.GetArrayLength() > 0 &&
                candidates[0].TryGetProperty("content", out var content) &&
                content.TryGetProperty("parts", out var parts) &&
                parts.GetArrayLength() > 0 &&
                parts[0].TryGetProperty("text", out var textElem))
            {
                return textElem.GetString();
            }

            return null;
        }

        private string GenerateKnowledgeResponse(string message)
        {
            var lower = (message ?? "").ToLowerInvariant().Trim();

            if (lower.Contains("bom") || lower.Contains("bill of material"))
            {
                return "### 📋 Bill of Materials (BOM) in NT-MMS\n\n" +
                       "The **Bill of Materials (BOM)** module defines the exact recipe of raw materials, sub-items, and quantities needed to produce a finished product.\n\n" +
                       "**Key Capabilities:**\n" +
                       "• **Header Details**: Select Finished Good (`ITEMMST`), Department (`LABOURMST`), and Store (`STOREMST`).\n" +
                       "• **Line Items**: Add raw materials with automatic calculations for consumption (`Qty × Consumption = Total Qty`).\n" +
                       "• **BOM Modes**: Supports both `JOB` (Jobwork / Project specific) and `REGULAR` production modes.\n" +
                       "• **BOM Follow-Up**: Monitor open vs. closed BOM records and batch-close completed orders.\n\n" +
                       "👉 Navigate via **Transactions ➔ Bill of Material (BOM)** to start!";
            }

            if (lower.Contains("purchase order") || lower.Contains("po ") || lower.EndsWith("po"))
            {
                return "### 🛒 Purchase Orders & Procurement Flow\n\n" +
                       "NT-MMS features a 3-step procurement cycle:\n\n" +
                       "1. **Generate Purchase Order**: Create POs specifying vendor (`PARTYMST`), delivery store, item rates, discounts, and payment conditions.\n" +
                       "2. **Release / Approve PO**: Multi-level authorization where management reviews and approves open purchase orders before dispatch.\n" +
                       "3. **PO Advance Entry**: Track and record advance disbursements to suppliers against generated POs.\n\n" +
                       "👉 Find these under **Transactions ➔ Purchase Order** & **PO Approval**.";
            }

            if (lower.Contains("stock transfer") || lower.Contains("transfer"))
            {
                return "### 🔄 Stock Transfer Across Warehouses\n\n" +
                       "Stock Transfer manages the movement of raw materials and finished goods between internal locations.\n\n" +
                       "**Highlights:**\n" +
                       "• Transfers decrement from `Source Store` and increment into `Destination Store` in the `STOCKREGNEW` inventory ledger.\n" +
                       "• Incorporates concurrency locking (`UPDLOCK, HOLDLOCK`) to prevent race conditions during peak hours.\n" +
                       "• Validates fiscal lock dates (`LOCKDATAMST`) to safeguard closed accounting periods.\n\n" +
                       "👉 Available in **Transactions ➔ Stock Transfer**.";
            }

            if (lower.Contains("indent") || lower.Contains("requisition"))
            {
                return "### 📑 Indents & Requisitions\n\n" +
                       "Indents represent internal purchase/material requests raised by factory departments:\n\n" +
                       "• **Raise Indent**: Departments specify required items, urgency level, and expected delivery dates.\n" +
                       "• **Indent Approval**: Authorizing managers approve or reject requests prior to PO conversion.\n\n" +
                       "👉 Go to **Transactions ➔ Indent Entry** and **Indent Approval**.";
            }

            if (lower.Contains("store") || lower.Contains("location") || lower.Contains("master"))
            {
                return "### 🏢 Master Catalogs in NT-MMS\n\n" +
                       "The system maintains 18 centralized master records:\n\n" +
                       "• **Store Master**: Physical warehouses, bins, and scrap yards.\n" +
                       "• **Location Master**: Plant sites, factory units, and vendor premises.\n" +
                       "• **Department Master**: Operational wings (Cutting, Weaving, Packing, Quality).\n" +
                       "• **Item & Fabric Masters**: Raw fabrics, finished goods, sizes, and maker brands.\n\n" +
                       "👉 Open any master record from the **Masters** section in the left navigation sidebar!";
            }

            if (lower.Contains("role") || lower.Contains("permission") || lower.Contains("user"))
            {
                return "### 🔐 Security & Access Control\n\n" +
                       "NT-MMS enforces strict Role-Based Access Control (RBAC):\n\n" +
                       "• **Admins (`IsAdmin = true`)**: Possess full operational bypass across all modules.\n" +
                       "• **Standard Roles**: Permissions are granted per module for 4 actions: **View** (GET), **Add** (POST), **Update** (PUT), and **Delete** (DELETE).\n" +
                       "• **Audit Trail**: Every role change is logged in `PermissionAuditLog`, and logins in `AuthAuditLog`.\n\n" +
                       "👉 Administrators can configure permissions in **User Management ➔ Roles & Permissions**.";
            }

            if (lower.Contains("hello") || lower.Contains("hi") || lower.Contains("hey") || lower.Contains("help"))
            {
                return "👋 **Hello! I am Gemini Copilot for NT-MMS.**\n\n" +
                       "I can help you navigate the system, explain business workflows (BOM, Purchase Orders, Indents, Stock Transfers), or answer any question.\n\n" +
                       "**What would you like to explore?**\n" +
                       "• *\"How do I create a Bill of Materials?\"*\n" +
                       "• *\"Explain the Purchase Order approval flow\"*\n" +
                       "• *\"How does Stock Transfer work across stores?\"*\n" +
                       "• *\"How are user permissions and roles assigned?\"*";
            }

            // General response
            return $"I understand you are asking about: **{message}**\n\n" +
                   "I am connected to your NT-MMS ERP environment. You can ask me about:\n" +
                   "• **Bill of Materials (BOM)** & manufacturing calculations\n" +
                   "• **Purchase Orders (PO)**, approvals, and supplier advances\n" +
                   "• **Stock Transfers** & warehouse inventory ledger\n" +
                   "• **Master Data** (Stores, Departments, Items, Locations)\n" +
                   "• **User Management** & permission matrices\n\n" +
                   "*💡 Tip: To enable full open-ended Gemini AI reasoning, you can add your free Gemini API Key in the settings or server configuration.*";
        }
    }
}
