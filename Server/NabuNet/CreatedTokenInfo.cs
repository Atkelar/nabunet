namespace NabuNet
{
    public class CreatedTokenInfo
        : TokenInfo
    {
        public CreatedTokenInfo(TokenInfo source)
        {
            this.ExpiresAt = source.ExpiresAt;
            this.IsContentManager = source.IsContentManager;
            this.IsModerator = source.IsModerator;
            this.IsSiteAdmin = source.IsSiteAdmin;
            this.IssuedAt = source.IssuedAt;
            this.IsUserAdmin = source.IsUserAdmin;
            this.Id = source.Id;
            this.Hash = source.Hash;
        }

        public string TokenSecretValue { get; set; }
    }
}