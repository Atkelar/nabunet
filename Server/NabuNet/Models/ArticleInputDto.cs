using System;
using System.ComponentModel.DataAnnotations;

namespace NabuNet.Models
{
    public class ArticleInputDto
    {
        [Required]
        [Display(Name = "Title")]
        public string Title { get; set; }

        [Display(Name = "Article")]
        public string? Article { get; set; }

        [Display(Name = "Reference Date")]
        public DateTime? ReferenceDate { get; set; }
    }
}