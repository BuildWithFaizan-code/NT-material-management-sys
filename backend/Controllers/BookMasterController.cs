using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class BookMasterController : ControllerBase
    {
        private readonly IBookMasterService _service;

        public BookMasterController(IBookMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/BookMaster/GetAllBooks
        /// Returns distinct list of books: BOOK_CODE, BOOK_NAME.
        /// </summary>
        [HttpGet("GetAllBooks")]
        [HttpGet]
        public async Task<IActionResult> GetAllBooks()
        {
            var books = await _service.GetAllBooksAsync();
            return Ok(ApiResponse<IEnumerable<BookMasterSummaryDto>>.Ok(books, "Book Master records fetched successfully."));
        }

        /// <summary>
        /// GET /api/BookMaster/GetAllBooksWithDetails
        /// Returns all books with assigned categories and series configuration.
        /// </summary>
        [HttpGet("GetAllBooksWithDetails")]
        public async Task<IActionResult> GetAllBooksWithDetails()
        {
            var books = await _service.GetAllBooksWithDetailsAsync();
            return Ok(ApiResponse<IEnumerable<BookDetailDto>>.Ok(books, "Book Master detailed records fetched successfully."));
        }

        /// <summary>
        /// GET /api/BookMaster/GetBookDetails/{bookCode}
        /// Returns single book record with assigned categories.
        /// </summary>
        [HttpGet("GetBookDetails/{bookCode:int}")]
        [HttpGet("{bookCode:int}")]
        public async Task<IActionResult> GetBookDetails(int bookCode)
        {
            var item = await _service.GetBookDetailsAsync(bookCode);
            if (item == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Book record with code #{bookCode} not found."));
            }
            return Ok(ApiResponse<BookDetailDto>.Ok(item));
        }

        /// <summary>
        /// GET /api/BookMaster/GetAvailableCategories/{bookCode}
        /// Returns list of categories unassigned for this book.
        /// </summary>
        [HttpGet("GetAvailableCategories/{bookCode:int}")]
        public async Task<IActionResult> GetAvailableCategories(int bookCode)
        {
            var categories = await _service.GetAvailableCategoriesAsync(bookCode);
            return Ok(ApiResponse<IEnumerable<CategoryDto>>.Ok(categories));
        }

        /// <summary>
        /// GET /api/BookMaster/GetNextBookCode
        /// Returns next available auto BOOK_CODE.
        /// </summary>
        [HttpGet("GetNextBookCode")]
        [HttpGet("next-code")]
        public async Task<IActionResult> GetNextBookCode()
        {
            var nextCode = await _service.GetNextBookCodeAsync();
            return Ok(ApiResponse<int>.Ok(nextCode, "Next Book Master code generated."));
        }

        /// <summary>
        /// POST /api/BookMaster/SaveBook
        /// Saves or updates BOOKMST and category allocations in BOOKDET atomically.
        /// </summary>
        [HttpPost("SaveBook")]
        [HttpPost]
        public async Task<IActionResult> SaveBook([FromBody] BookSaveDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.BookName))
            {
                return BadRequest(ApiResponse<string>.Fail("Book Name is required."));
            }

            var success = await _service.SaveBookAsync(model);
            if (!success)
            {
                return BadRequest(ApiResponse<string>.Fail("Failed to save Book Master record."));
            }

            return Ok(ApiResponse<string>.Ok("Book Master saved to SQL Server successfully."));
        }

        /// <summary>
        /// DELETE /api/BookMaster/DeleteBook/{bookCode}
        /// Deletes record from BOOKDET and BOOKMST.
        /// </summary>
        [HttpDelete("DeleteBook/{bookCode:int}")]
        [HttpDelete("{bookCode:int}")]
        public async Task<IActionResult> DeleteBook(int bookCode)
        {
            var success = await _service.DeleteBookAsync(bookCode);
            if (!success)
            {
                return NotFound(ApiResponse<string>.Fail($"Book Master with code #{bookCode} not found or delete failed."));
            }
            return Ok(ApiResponse<string>.Ok("Book Master deleted successfully."));
        }
    }
}
