using System.ComponentModel.DataAnnotations;

namespace NabuNet.Models
{
    public class ConfirmMailForAccountModel
    {
        public string UserName { get; set; }
        public string? EMail { get; set; }
        [Display(Name = "Valiation Code")]
        public string ValidationCode { get; set; }
        [Required]
        [Display(Name = "Password")]
        public string Password { get; set; }
        public string Token { get; set; }
    }
}