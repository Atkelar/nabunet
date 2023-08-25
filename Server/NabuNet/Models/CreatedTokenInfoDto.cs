namespace NabuNet.Models
{
    public class CreatedTokenInfoDto : TokenInfoDto
    {
        internal CreatedTokenInfoDto(CreatedTokenInfo source)
        {
            this.Name = source.Name;
            this.ExpiresAt = source.ExpiresAt;
            this.IsContentManager = source.IsContentManager;
            this.IsModerator = source.IsModerator;
            this.IsSiteAdmin = source.IsSiteAdmin;
            this.IssuedAt = source.IssuedAt;
            this.IsUserAdmin = source.IsUserAdmin;
            this.Secret = source.TokenSecretValue;
            this.Id = source.Id.ToString("n");
        }
        public string Secret { get; set; }
    }
}