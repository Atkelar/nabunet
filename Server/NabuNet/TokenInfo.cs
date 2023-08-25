using System;

namespace NabuNet
{
    public class TokenInfo
    {
        public Guid Id { get; set; }
        public DateTime IssuedAt { get; set; }
        public DateTime? ExpiresAt { get; set; }
        public bool IsSiteAdmin { get; set; }
        public bool IsContentManager { get; set; }
        public bool IsModerator { get; set; }
        public bool IsUserAdmin { get; set; }
        public string Hash { get; set; }
        public string Name { get; set; }
    }
}