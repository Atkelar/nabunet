using System;
using System.ComponentModel.DataAnnotations;

namespace NabuNet.Models
{
    public class NewTokenInputDto
    {
        [Display(Name = "Token Name")]
        [StringLength(32)]
        public string? Name { get; set; }
        [Display(Name = "Expiratin time (UTC)")]
        public DateTime? Expires { get; set; }
        [Display(Name = "Site Admin")]
        public bool MakeSiteAdmin { get; set; }
        [Display(Name = "Moderator")]
        public bool MakeModerator { get; set; }
        [Display(Name = "Content Admin")]
        public bool MakeContentManager { get; set; }
        [Display(Name = "User Admin")]
        public bool MakeUserAdmin { get; set; }
    }
}