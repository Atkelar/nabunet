using System;
using System.ComponentModel.DataAnnotations;

namespace NabuNet.Models
{
    public class ImprintDto
    {
        [Required]
        [Display(Name = "Title")]
        public string Title { get; set; }

        [Required]
        [Display(Name = "Content")]
        public string Article { get; set; }

    }
}