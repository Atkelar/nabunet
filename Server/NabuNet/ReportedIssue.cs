using System;

namespace NabuNet
{
    public class ReportedIssue
        : IKeyRecord
    {
        public string? Id { get; set; }

        public string DeriveNewKey()
        {
            return $"{TopicCode}-{CreatedAt.Ticks.ToString("x8")}";
        }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public string? UserName { get; set; }
        public string RelatedUser { get; set; }
        public string TopicCode { get; set; }
        public string Message { get; set; }
    }
}