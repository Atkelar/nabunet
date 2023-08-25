using System.ComponentModel.DataAnnotations;

namespace NabuNet
{

    public class TemplateContent
    {
        [Required]
        [MaxLength(1024)]
        [RegularExpression(@"^[^\n\r]+$")]
        public string Subject { get; set; }
        [Required]
        public string Body { get; set; }
    }
}