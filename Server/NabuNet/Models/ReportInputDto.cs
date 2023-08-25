using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace NabuNet.Models
{
    public class ReportInputDto
    {
        public bool WarnUserMismatch { get; internal set; }
        public string? UserName { get; internal set; }
        public string Topic { get; internal set; }

        [DisplayName("Message")]
        [MaxLength(10240)]
        public string? Message { get; set; }

        public string TopicCode { get; internal set; }
    }
}