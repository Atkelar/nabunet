using System;
using System.Collections.Generic;
using System.Linq;

namespace NabuNet.Models
{
    internal class TokenListDto
    {
        public TokenListDto(UserProfile userProfile, IEnumerable<TokenInfo> list)
        {
            CanMakeSiteAdmin = userProfile.IsAdministrator;
            CanMakeModerator = userProfile.IsAdministrator || userProfile.IsModerator;
            CanMakeContentManager = userProfile.IsAdministrator || userProfile.IsContentManager;
            CanMakeUserAdmin = userProfile.IsAdministrator || userProfile.IsUserAdministrator;
            Tokens = new List<TokenInfoDto>();
            Tokens.AddRange(list.Select(x => new TokenInfoDto()
            {
                IssuedAt = x.IssuedAt,
                ExpiresAt = x.ExpiresAt,
                Name = x.Name,
                Id = x.Id.ToString("n"),
                IsContentManager = x.IsContentManager,
                IsModerator = x.IsModerator,
                IsUserAdmin = x.IsUserAdmin,
                IsSiteAdmin = x.IsSiteAdmin
            }));
        }

        public List<TokenInfoDto> Tokens { get; set; }

        public bool CanMakeSiteAdmin { get; set; }
        public bool CanMakeUserAdmin { get; set; }
        public bool CanMakeContentManager { get; set; }
        public bool CanMakeModerator { get; set; }
    }

    public class TokenInfoDto
    {
        public string Id { get; set; }
        public DateTime IssuedAt { get; set; }
        public DateTime? ExpiresAt { get; set; }
        public string Name { get; set; }
        public bool IsContentManager { get; set; }
        public bool IsModerator { get; set; }
        public bool IsUserAdmin { get; set; }
        public bool IsSiteAdmin { get; set; }

        public bool AnySpecials { get => IsContentManager || IsModerator || IsUserAdmin || IsSiteAdmin; }
    }
}