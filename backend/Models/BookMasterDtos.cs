namespace MMSERP.Api.Models
{
    public class BookMasterSummaryDto
    {
        public int BookCode { get; set; }
        public string BookName { get; set; } = string.Empty;
        public string? Grn { get; set; }
        public string? Issue { get; set; }
        public string? JobIssue { get; set; }
        public string? JobReceipt { get; set; }
    }

    public class CategoryDto
    {
        public int CatCode { get; set; }
        public string CatName { get; set; } = string.Empty;
    }

    public class BookDetailDto
    {
        public int BookCode { get; set; }
        public string BookName { get; set; } = string.Empty;
        public string? Grn { get; set; } = string.Empty;
        public string? Issue { get; set; } = string.Empty;
        public string? JobIssue { get; set; } = string.Empty;
        public string? JobReceipt { get; set; } = string.Empty;
        public List<CategoryDto> Categories { get; set; } = new();
    }

    public class BookSaveDto
    {
        public int BookCode { get; set; }
        public string BookName { get; set; } = string.Empty;
        public string? Grn { get; set; } = string.Empty;
        public string? Issue { get; set; } = string.Empty;
        public string? JobIssue { get; set; } = string.Empty;
        public string? JobReceipt { get; set; } = string.Empty;
        public List<int> SelectedCatCodes { get; set; } = new();
    }
}
